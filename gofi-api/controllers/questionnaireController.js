const mysql = require("mysql2/promise");

// ---------------- DB: konfiguracja + pojedynczy pool ---------------- //

const DB_CONFIG = {
  host: process.env.DB_HOST || "localhost",
  user: process.env.DB_USER || "root",
  password: process.env.DB_PASS || "",
  database: process.env.DB_NAME || "gofi",
};

let _pool;
function getDbPool() {
  if (!_pool) {
    _pool = mysql.createPool(DB_CONFIG);
  }
  return _pool;
}

// ---------------- Ankieta: definicja pytań ---------------- //

const QUESTIONS = [
  {
    id: "goal",
    type: "single",
    label: "Jaki jest Twój główny cel?",
    options: [
      { value: "reduction", label: "Redukcja" },
      { value: "mass", label: "Masa" },
      { value: "recomposition", label: "Rekompozycja" },
    ],
  },
  {
    id: "experience",
    type: "single",
    label: "Doświadczenie",
    options: [
      { value: "beginner", label: "Początkujący" },
      { value: "intermediate", label: "Średnio-zaawansowany" },
      { value: "advanced", label: "Zaawansowany" },
    ],
  },
  {
    id: "days_per_week",
    type: "number",
    label: "Dni w tygodniu",
    min: 2,
    max: 7,
  },
  {
    id: "session_time",
    type: "number",
    label: "Minuty na sesję",
    min: 20,
    max: 120,
  },
  {
    id: "location",
    type: "single",
    label: "Gdzie ćwiczysz?",
    options: [
      { value: "home", label: "Dom" },
      { value: "gym", label: "Siłownia" },
    ],
  },
  {
    id: "equipment",
    type: "multi",
    label: "Sprzęt",
    showIf: { location: ["home", "gym"] },
    options: [
      { value: "none", label: "Brak" },
      { value: "dumbbells", label: "Hantle" },
      { value: "barbell", label: "Sztanga" },
      { value: "machines", label: "Maszyny" },
      { value: "bands", label: "Gumy" },
    ],
  },
  {
    id: "preference_style",
    type: "single",
    label: "Preferowany typ",
    options: [
      { value: "strength", label: "Siłowe" },
      { value: "cardio", label: "Cardio" },
      { value: "mixed", label: "Mieszane" },
    ],
  },
  {
    id: "daily_activity",
    type: "single",
    label: "Aktywność dzienna",
    options: [
      { value: "low", label: "Niska" },
      { value: "medium", label: "Średnia" },
      { value: "high", label: "Wysoka" },
    ],
  },
  { id: "age", type: "number", label: "Wiek", min: 14, max: 100 },
  {
    id: "intensity_pref",
    type: "single",
    label: "Preferowana intensywność",
    options: [
      { value: "low", label: "Niska" },
      { value: "medium", label: "Średnia" },
      { value: "high", label: "Wysoka" },
    ],
  },
  {
    id: "focus_body",
    type: "single",
    label: "Akcent sylwetkowy",
    options: [
      { value: "upper", label: "Góra" },
      { value: "lower", label: "Dół" },
      { value: "balanced", label: "Równo" },
    ],
  },
];

// ---------------- Walidacja odpowiedzi z ankiety ---------------- //

function validateAnswers(a) {
  const errors = [];

  const goals = ["reduction", "mass", "recomposition"];
  if (!goals.includes(a.goal)) errors.push("Invalid goal");

  if (
    typeof a.days_per_week !== "number" ||
    a.days_per_week < 2 ||
    a.days_per_week > 7
  ) {
    errors.push("days_per_week out of range (2–7)");
  }

  if (
    typeof a.session_time !== "number" ||
    a.session_time < 20 ||
    a.session_time > 120
  ) {
    errors.push("session_time out of range (20–120)");
  }

  const exps = ["beginner", "intermediate", "advanced"];
  if (!exps.includes(a.experience)) errors.push("Invalid experience");

  const locs = ["home", "gym"];
  if (!locs.includes(a.location)) errors.push("Invalid location");

  if (typeof a.age === "number" && (a.age < 14 || a.age > 100)) {
    errors.push("age out of range (14–100)");
  }

  const intens = ["low", "medium", "high"];
  if (a.intensity_pref && !intens.includes(a.intensity_pref)) {
    errors.push("Invalid intensity_pref");
  }

  const styles = ["strength", "cardio", "mixed"];
  if (a.preference_style && !styles.includes(a.preference_style)) {
    errors.push("Invalid preference_style");
  }

  const focuses = ["upper", "lower", "balanced"];
  if (a.focus_body && !focuses.includes(a.focus_body)) {
    errors.push("Invalid focus_body");
  }

  return errors;
}

// ---------------- Logika treningowa: serie, powtórzenia, split ---------------- //

// liczba serii bazowa zależna od doświadczenia i preferowanej intensywności
function baseSets(experience, intensity_pref) {
  let sets = 3;
  if (experience === "intermediate") sets = 4;
  if (experience === "advanced") sets = 5;

  if (intensity_pref === "low") sets -= 1;
  if (sets < 2) sets = 2;

  return sets;
}

// sugerowany zakres powtórzeń zależny od celu, wzorca, intensywności i doświadczenia
function suggestReps(goal, pattern, intensity_pref, experience) {
  let reps;

  if (goal === "mass") {
    reps = pattern === "squat" || pattern === "hinge" ? "6–8" : "8–12";
  } else if (goal === "reduction") {
    reps = "10–15";
  } else {
    reps = "8–12";
  }

  // modyfikacja intensywnością
  if (intensity_pref === "low") {
    if (reps === "6–8") reps = "8–10";
    else reps = "10–15";
  } else if (
    intensity_pref === "high" &&
    ["squat", "hinge", "push_h", "pull_h"].includes(pattern)
  ) {
    reps = "5–8";
  }

  // początkujący nie dostają ultra niskich zakresów
  if (experience === "beginner" && reps === "5–8") reps = "6–8";

  return reps;
}

// wybór splita na podstawie celu i liczby dni
function pickSplit(goal, days) {
  if (days <= 3) return "FBW"; // 2–3 dni: full body
  if (goal === "mass" || goal === "recomposition") {
    return days >= 5 ? "PPL" : "ULUL";
  }
  if (goal === "reduction") {
    return days >= 4 ? "ULUL" : "FBW";
  }
  return "FBW";
}

// podsumowanie profilu
function profileSummary(answers) {
  return {
    goal: answers.goal,
    experience: answers.experience,
    days: answers.days_per_week,
    session: answers.session_time,
    location: answers.location,
    equipment: answers.equipment || [],
  };
}

// 4-tygodniowa progresja
function generateProgressionNotes() {
  return [
    {
      week: 1,
      note: "Tydzień 1: Umiarkowana intensywność, skup się na technice i poznaniu ćwiczeń.",
    },
    {
      week: 2,
      note: "Tydzień 2: Delikatnie zwiększ obciążenia lub liczbę powtórzeń (~5–10%).",
    },
    {
      week: 3,
      note: "Tydzień 3: Trenuj bliżej upadku mięśniowego w ostatnich seriach (RIR 1–2).",
    },
    {
      week: 4,
      note: "Tydzień 4: Deload – zmniejsz ciężary o ok. 20–30%, utrzymaj technikę i regenerację.",
    },
  ];
}

// ---------------- Wybór ćwiczeń na pojedynczy dzień ---------------- //

async function pickExercisesForDay(
  pool,
  userAnswers,
  { targetPatterns, muscleBias, maxMinutes }
) {
  const location = userAnswers.location || "home";
  const equipmentSet = new Set([
    ...(userAnswers.equipment || []),
    "bodyweight",
    "none",
  ]);

  const placeholders = targetPatterns.map(() => "?").join(",");

  const [rows] = await pool.query(
    `SELECT code, name, muscle_group, pattern, equipment, location, difficulty, minutes_est
     FROM exercises
     WHERE pattern IN (${placeholders})
       AND FIND_IN_SET(?, location)`,
    [...targetPatterns, location]
  );

  // filtr po sprzęcie
  const viable = rows.filter((ex) => {
    const requiredEquip = (ex.equipment || "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
    return (
      requiredEquip.length === 0 ||
      requiredEquip.some((eq) => equipmentSet.has(eq))
    );
  });

  // filtr trudności / sortowanie po doświadczeniu
  const exp = userAnswers.experience;
  let filtered = viable;
  if (exp === "beginner") {
    filtered = viable.filter((ex) => ex.difficulty <= 3);
  }

  const biasSet = new Set(muscleBias || []);
  filtered.sort((a, b) => {
    const aBias = biasSet.has(a.muscle_group) ? 0 : 1;
    const bBias = biasSet.has(b.muscle_group) ? 0 : 1;
    if (aBias !== bBias) return aBias - bBias;

    if (exp === "advanced") {
      return b.difficulty - a.difficulty; // zaawansowany: trudniejsze wyżej
    }
    return a.difficulty - b.difficulty; // pocz./średnio: łatwiejsze wyżej
  });

  // dopuszczalny czas sesji z uwzględnieniem aktywności i wieku
  let allowedMinutes = maxMinutes || 60;

  if (
    userAnswers.daily_activity === "high" &&
    userAnswers.goal === "reduction"
  ) {
    allowedMinutes = Math.min(allowedMinutes, 45);
  }
  if (userAnswers.daily_activity === "low" && userAnswers.goal === "mass") {
    allowedMinutes += 10;
  }
  if (typeof userAnswers.age === "number" && userAnswers.age >= 55) {
    allowedMinutes -= 5;
  }
  if (allowedMinutes < 30) allowedMinutes = 30;

  const picked = [];
  let totalMinutes = 0;
  const minExercises = 3; // miękki warunek: chcemy min. 3 ćwiczenia
  const maxExercises = 5;

  for (const ex of filtered) {
    const estMin = ex.minutes_est || 6;
    const wouldExceed = totalMinutes + estMin > allowedMinutes;

    if (picked.length >= minExercises && wouldExceed) {
      break;
    }

    picked.push(ex);
    totalMinutes += estMin;

    if (picked.length >= maxExercises) break;
  }

  const sets = baseSets(userAnswers.experience, userAnswers.intensity_pref);

  return picked.map((ex) => ({
    code: ex.code,
    name: ex.name,
    sets,
    reps: suggestReps(
      userAnswers.goal,
      ex.pattern,
      userAnswers.intensity_pref,
      userAnswers.experience
    ),
  }));
}

// ---------------- Generowanie tygodnia z bazy (FBW / ULUL / PPL) ---------------- //

async function generateWeekFromDb(pool, split, answers) {
  const days = answers.days_per_week;
  const maxMin = answers.session_time || 60;

  let biasMuscles;
  if (answers.focus_body === "upper") {
    biasMuscles = ["chest", "back", "shoulders", "arms"];
  } else if (answers.focus_body === "lower") {
    biasMuscles = ["legs", "core"];
  } else {
    biasMuscles = ["chest", "back", "legs", "shoulders", "core", "arms"];
  }

  const weekPlan = [];

  if (split === "FBW") {
    const patternsA = ["squat", "push_h", "pull_h"];
    const patternsB = ["hinge", "push_v", "pull_v"];

    if (days <= 2) {
      const mon = await pickExercisesForDay(pool, answers, {
        targetPatterns: patternsA,
        muscleBias: biasMuscles,
        maxMinutes: maxMin,
      });
      const thu = await pickExercisesForDay(pool, answers, {
        targetPatterns: patternsB,
        muscleBias: biasMuscles,
        maxMinutes: maxMin,
      });
      weekPlan.push({ day: "Mon", exercises: mon });
      weekPlan.push({ day: "Thu", exercises: thu });
    } else {
      const a = await pickExercisesForDay(pool, answers, {
        targetPatterns: patternsA,
        muscleBias: biasMuscles,
        maxMinutes: maxMin,
      });
      const b = await pickExercisesForDay(pool, answers, {
        targetPatterns: patternsB,
        muscleBias: biasMuscles,
        maxMinutes: maxMin,
      });
      weekPlan.push({ day: "Mon", exercises: a });
      weekPlan.push({ day: "Wed", exercises: b });
      weekPlan.push({ day: "Fri", exercises: a });
    }
  } else if (split === "ULUL") {
    const patternsUpperA = ["push_h", "pull_h", "push_v"];
    const patternsLowerA = ["squat", "hinge", "core"];
    const patternsUpperB = ["pull_v", "push_h", "pull_h"];
    let patternsLowerB = ["squat", "hinge", "core"];
    if (days >= 4) {
      patternsLowerB = ["hinge", "lunge", "core"];
    }

    const upperA = await pickExercisesForDay(pool, answers, {
      targetPatterns: patternsUpperA,
      muscleBias: biasMuscles,
      maxMinutes: maxMin,
    });
    weekPlan.push({ day: "Mon", block: "Upper A", exercises: upperA });

    const lowerA = await pickExercisesForDay(pool, answers, {
      targetPatterns: patternsLowerA,
      muscleBias: biasMuscles,
      maxMinutes: maxMin,
    });
    weekPlan.push({ day: "Tue", block: "Lower A", exercises: lowerA });

    const upperA_usedCodes = new Set(upperA.map((ex) => ex.code));
    const upperB = await pickExercisesForDay(pool, answers, {
      targetPatterns: patternsUpperB,
      muscleBias: biasMuscles,
      maxMinutes: maxMin,
    });
    let upperB_final = upperB.filter((ex) => !upperA_usedCodes.has(ex.code));
    if (upperB_final.length < 3) {
      // za mało ćwiczeń po odfiltrowaniu – bierzemy pełną listę
      upperB_final = upperB;
    }
    weekPlan.push({ day: "Thu", block: "Upper B", exercises: upperB_final });
    const lowerA_usedCodes = new Set(lowerA.map((ex) => ex.code));
    const lowerB = await pickExercisesForDay(pool, answers, {
      targetPatterns: patternsLowerB,
      muscleBias: biasMuscles,
      maxMinutes: maxMin,
    });
    let lowerB_final = lowerB.filter((ex) => !lowerA_usedCodes.has(ex.code));
    if (lowerB_final.length < 3) {
      lowerB_final = lowerB;
    }
    weekPlan.push({ day: "Fri", block: "Lower B", exercises: lowerB_final });

    if (days > 4) {
      if (days >= 5) {
        const condMid = await pickExercisesForDay(pool, answers, {
          targetPatterns: ["carry", "accessory", "core"],
          muscleBias: [],
          maxMinutes: Math.floor(maxMin / 2),
        });
        weekPlan.splice(2, 0, {
          day: "Wed",
          block: "Conditioning",
          exercises: condMid,
        });
      }
      if (days >= 6) {
        const condEnd = await pickExercisesForDay(pool, answers, {
          targetPatterns: ["carry", "accessory", "core"],
          muscleBias: [],
          maxMinutes: Math.floor(maxMin / 2),
        });
        weekPlan.push({
          day: "Sat",
          block: "Conditioning",
          exercises: condEnd,
        });
      }
    }
  } else if (split === "PPL") {
    if (days === 5) {
      const push = await pickExercisesForDay(pool, answers, {
        targetPatterns: ["push_h", "push_v"],
        muscleBias: biasMuscles,
        maxMinutes: maxMin,
      });
      weekPlan.push({ day: "Mon", block: "Push", exercises: push });

      const pull = await pickExercisesForDay(pool, answers, {
        targetPatterns: ["pull_h", "pull_v"],
        muscleBias: biasMuscles,
        maxMinutes: maxMin,
      });
      weekPlan.push({ day: "Tue", block: "Pull", exercises: pull });

      const legs = await pickExercisesForDay(pool, answers, {
        targetPatterns: ["squat", "hinge", "core"],
        muscleBias: biasMuscles,
        maxMinutes: maxMin,
      });
      weekPlan.push({ day: "Wed", block: "Legs", exercises: legs });

      const usedPushCodes = new Set(push.map((ex) => ex.code));
      const pushVol = await pickExercisesForDay(pool, answers, {
        targetPatterns: ["push_h", "push_v", "core"],
        muscleBias: ["chest", "shoulders", "core"],
        maxMinutes: maxMin,
      });
      let pushVolFinal = pushVol.filter((ex) => !usedPushCodes.has(ex.code));
      if (pushVolFinal.length < 3) {
        pushVolFinal = pushVol;
      }
      weekPlan.push({
        day: "Fri",
        block: "Push (vol)",
        exercises: pushVolFinal,
      });

      const usedPullCodes = new Set(pull.map((ex) => ex.code));
      const pullVol = await pickExercisesForDay(pool, answers, {
        targetPatterns: ["pull_h", "pull_v", "core"],
        muscleBias: ["back", "core"],
        maxMinutes: maxMin,
      });
      let pullVolFinal = pullVol.filter((ex) => !usedPullCodes.has(ex.code));
      if (pullVolFinal.length < 3) {
        pullVolFinal = pullVol;
      }
      weekPlan.push({
        day: "Sat",
        block: "Pull (vol)",
        exercises: pullVolFinal,
      });
    } else if (days === 6) {
      const pushA = await pickExercisesForDay(pool, answers, {
        targetPatterns: ["push_h", "push_v"],
        muscleBias: biasMuscles,
        maxMinutes: maxMin,
      });
      weekPlan.push({ day: "Mon", block: "Push A", exercises: pushA });

      const pullA = await pickExercisesForDay(pool, answers, {
        targetPatterns: ["pull_h", "pull_v"],
        muscleBias: biasMuscles,
        maxMinutes: maxMin,
      });
      weekPlan.push({ day: "Tue", block: "Pull A", exercises: pullA });

      const legsA = await pickExercisesForDay(pool, answers, {
        targetPatterns: ["squat", "hinge", "core"],
        muscleBias: biasMuscles,
        maxMinutes: maxMin,
      });
      weekPlan.push({ day: "Wed", block: "Legs A", exercises: legsA });

      const usedPushA = new Set(pushA.map((ex) => ex.code));
      const pushB = await pickExercisesForDay(pool, answers, {
        targetPatterns: ["push_h", "push_v", "core"],
        muscleBias: biasMuscles,
        maxMinutes: maxMin,
      });
      const pushBFinal = pushB.filter((ex) => !usedPushA.has(ex.code));
      weekPlan.push({ day: "Thu", block: "Push B", exercises: pushBFinal });

      const usedPullA = new Set(pullA.map((ex) => ex.code));
      const pullB = await pickExercisesForDay(pool, answers, {
        targetPatterns: ["pull_h", "pull_v", "core"],
        muscleBias: biasMuscles,
        maxMinutes: maxMin,
      });
      const pullBFinal = pullB.filter((ex) => !usedPullA.has(ex.code));
      weekPlan.push({ day: "Fri", block: "Pull B", exercises: pullBFinal });

      const usedLegsA = new Set(legsA.map((ex) => ex.code));
      const legsB = await pickExercisesForDay(pool, answers, {
        targetPatterns: ["squat", "hinge", "lunge"],
        muscleBias: biasMuscles,
        maxMinutes: maxMin,
      });
      let legsBFinal = legsB.filter((ex) => !usedLegsA.has(ex.code));
      if (legsBFinal.length < 3) {
        legsBFinal = legsB;
      }
      weekPlan.push({ day: "Sat", block: "Legs B", exercises: legsBFinal });
    } else if (days >= 7) {
      const basePlan = await generateWeekFromDb(pool, "PPL", {
        ...answers,
        days_per_week: 6,
      });
      weekPlan.push(...basePlan);

      if (
        answers.goal === "reduction" ||
        answers.preference_style === "cardio"
      ) {
        const condDay = await pickExercisesForDay(pool, answers, {
          targetPatterns: ["carry", "accessory", "core"],
          muscleBias: [],
          maxMinutes: maxMin,
        });
        weekPlan.push({
          day: "Sun",
          block: "Conditioning",
          exercises: condDay,
        });
      } else {
        const accessoryDay = await pickExercisesForDay(pool, answers, {
          targetPatterns: ["accessory", "core"],
          muscleBias: [],
          maxMinutes: Math.floor(maxMin / 2),
        });
        weekPlan.push({
          day: "Sun",
          block: "Accessory / Mobility",
          exercises: accessoryDay,
        });
      }
    }
  }

  // UWAGA: tutaj celowo usunąłem wcześniejszy „cardio finisher”
  // który korzystał z equipmentSet i muscle_group w strukturze,
  // bo w aktualnej wersji dzienne plany nie przenoszą tych pól.
  // Jeśli będziesz chciał, możemy go potem odtworzyć poprawnie.

  return weekPlan;
}

// ---------------- ROUTES: eksportowane handlery ---------------- //

// 1. Zwraca strukturę ankiety
exports.getQuestions = async (_req, res) => {
  res.json(QUESTIONS);
};

// 2. Główne: zapisuje odpowiedzi + generuje plan
exports.submitAnswers = async (req, res) => {
  try {
    const answers = req.body || {};
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ error: "Unauthorized" });

    const errors = validateAnswers(answers);
    if (errors.length) {
      return res
        .status(400)
        .json({ error: "Validation failed", details: errors });
    }

    const pool = getDbPool();

    const [qResult] = await pool.query(
      "INSERT INTO questionnaires (user_id, answers_json) VALUES (?, ?)",
      [userId, JSON.stringify(answers)]
    );
    const questionnaireId = qResult.insertId;

    const split = pickSplit(answers.goal, answers.days_per_week);
    const week = await generateWeekFromDb(pool, split, answers);
    const progression = generateProgressionNotes();

    const plan = { split, week, progression };

    const [pResult] = await pool.query(
      "INSERT INTO plans (user_id, source_questionnaire_id, plan_json) VALUES (?, ?, ?)",
      [userId, questionnaireId, JSON.stringify(plan)]
    );

    res.json({
      profile: profileSummary(answers),
      plan,
      ids: { questionnaireId, planId: pResult.insertId },
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Questionnaire submit failed" });
  }
};

// 3. Zwraca ostatnio wygenerowany plan
exports.getLatestPlan = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ error: "Unauthorized" });

    const pool = getDbPool();
    const [rows] = await pool.query(
      "SELECT plan_json FROM plans WHERE user_id=? ORDER BY id DESC LIMIT 1",
      [userId]
    );
    if (!rows.length) return res.json({});

    const raw = rows[0].plan_json;
    const latestPlan = typeof raw === "string" ? JSON.parse(raw) : raw;

    return res.json(latestPlan);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "getLatestPlan failed" });
  }
};

// 4. Tylko zapisuje odpowiedzi (bez generowania planu)
exports.saveAnswers = async (req, res) => {
  try {
    const answers = req.body || {};
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ error: "Unauthorized" });

    const pool = getDbPool();
    const [qResult] = await pool.query(
      "INSERT INTO questionnaires (user_id, answers_json) VALUES (?, ?)",
      [userId, JSON.stringify(answers)]
    );
    return res.json({ ok: true, questionnaireId: qResult.insertId });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "saveAnswers failed" });
  }
};

// 5. Zwraca ostatnie odpowiedzi ankiety (do wypełnienia formularza)
exports.getLatestAnswers = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ error: "Unauthorized" });

    const pool = getDbPool();
    const [rows] = await pool.query(
      "SELECT answers_json FROM questionnaires WHERE user_id=? ORDER BY id DESC LIMIT 1",
      [userId]
    );

    let latestAnswers = {};
    if (rows.length) {
      const raw = rows[0].answers_json;
      latestAnswers = typeof raw === "string" ? JSON.parse(raw) : raw;
    }

    res.json(latestAnswers);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "getLatestAnswers failed" });
  }
};
