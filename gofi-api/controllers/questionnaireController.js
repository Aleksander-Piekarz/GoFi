const mysql = require("mysql2/promise");
const fs = require("fs");
const path = require("path");
const { pool } = require("../lib/db");



// ---------------- Alternatywy ---------------- //

let ALTERNATIVES_MAP = new Map();

function loadAlternatives() {
  try {
    const altPath = path.join(
      __dirname,
      "..",
      "data",
      "exercise_alternatives.json"
    );
    const altData = fs.readFileSync(altPath, "utf8");
    const pairs = JSON.parse(altData);

    const map = new Map();

    for (const pairList of pairs) {
      for (const exerciseCode of pairList) {
        if (!map.has(exerciseCode)) {
          map.set(exerciseCode, new Set());
        }
        const alternatives = map.get(exerciseCode);
        for (const altCode of pairList) {
          if (exerciseCode !== altCode) {
            alternatives.add(altCode);
          }
        }
      }
    }

    ALTERNATIVES_MAP = map;
    console.log(
      `[GoFi] Pomyślnie załadowano ${map.size} ćwiczeń z alternatywami.`
    );
  } catch (err) {
    console.error(
      "[GoFi BŁĄD] Nie udało się załadować exercise_alternatives.json:",
      err.message
    );
  }
}

loadAlternatives();

// ---------------- Ankieta: definicja pytań ---------------- //
// (Bez zmian)
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
      { value: "kettlebell", label: "Kettlebell" },
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

// ---------------- Definicje Splitów ---------------- //
const SPLIT_TEMPLATES = {
  FBW_2: {
    name: "Full Body Workout (2x/week)",
    schedule: ["A", "B"],
    days: ["Mon", "Thu"],
    blocks: {
      A: { patterns: ["squat", "push_h", "pull_h", "core"], min_ex: 3, max_ex: 5 },
      B: { patterns: ["hinge", "push_v", "pull_v", "accessory"], min_ex: 3, max_ex: 5 },
    },
  },
  FBW_3: {
    name: "Full Body Workout (3x/week)",
    schedule: ["A", "B", "A"],
    days: ["Mon", "Wed", "Fri"],
    blocks: {
      A: { patterns: ["squat", "push_h", "pull_h", "core"], min_ex: 3, max_ex: 5 },
      B: { patterns: ["hinge", "push_v", "pull_v", "accessory"], min_ex: 3, max_ex: 5 },
    },
  },
  ULUL_4: {
    name: "Upper/Lower (4x/week)",
    schedule: ["Upper A", "Lower A", "Upper B", "Lower B"],
    days: ["Mon", "Tue", "Thu", "Fri"],
    blocks: {
      "Upper A": { patterns: ["push_h", "pull_h", "push_v", "accessory"], min_ex: 4, max_ex: 5 },
      "Lower A": { patterns: ["squat", "hinge", "lunge", "core"], min_ex: 3, max_ex: 4 },
      "Upper B": { patterns: ["pull_v", "push_h", "pull_h", "accessory"], min_ex: 4, max_ex: 5 },
      "Lower B": { patterns: ["hinge", "squat", "lunge", "core"], min_ex: 3, max_ex: 4 },
    },
  },
  PPL_3: {
    name: "Push/Pull/Legs (3x/week)",
    schedule: ["Push", "Pull", "Legs"],
    days: ["Mon", "Wed", "Fri"],
    blocks: {
      Push: { patterns: ["push_h", "push_v", "accessory"], min_ex: 4, max_ex: 5 },
      Pull: { patterns: ["pull_h", "pull_v", "accessory"], min_ex: 4, max_ex: 5 },
      Legs: { patterns: ["squat", "hinge", "lunge", "core"], min_ex: 4, max_ex: 5 },
    },
  },
  PPL_6: {
    name: "Push/Pull/Legs (6x/week)",
    schedule: ["Push A", "Pull A", "Legs A", "Push B", "Pull B", "Legs B"],
    days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
    blocks: {
      "Push A": { patterns: ["push_h", "push_v", "accessory"], min_ex: 4, max_ex: 5 },
      "Pull A": { patterns: ["pull_h", "pull_v", "accessory"], min_ex: 4, max_ex: 5 },
      "Legs A": { patterns: ["squat", "hinge", "lunge", "core"], min_ex: 4, max_ex: 5 },
      "Push B": { patterns: ["push_v", "push_h", "accessory"], min_ex: 4, max_ex: 5 },
      "Pull B": { patterns: ["pull_v", "pull_h", "accessory"], min_ex: 4, max_ex: 5 },
      "Legs B": { patterns: ["hinge", "squat", "lunge", "core"], min_ex: 4, max_ex: 5 },
    },
  },
};

// ---------------- Logika pomocnicza (Walidacja, Serie, Reps) ---------------- //
// (Bez zmian)
function validateAnswers(a) {
  const errors = [];
  const goals = ["reduction", "mass", "recomposition"];
  if (!goals.includes(a.goal)) errors.push("Invalid goal");
  if (typeof a.days_per_week !== "number" || a.days_per_week < 2 || a.days_per_week > 7) {
    errors.push("days_per_week out of range (2–7)");
  }
  if (typeof a.session_time !== "number" || a.session_time < 20 || a.session_time > 120) {
    errors.push("session_time out of range (20–120)");
  }
  const exps = ["beginner", "intermediate", "advanced"];
  if (!exps.includes(a.experience)) errors.push("Invalid experience");
  const locs = ["home", "gym"];
  if (!locs.includes(a.location)) errors.push("Invalid location");
  if (typeof a.age === "number" && (a.age < 14 || a.age > 100)) {
    errors.push("age out of range (14–100)");
  }
  return errors;
}

function baseSets(experience, intensity_pref) {
  let sets = 3;
  if (experience === "intermediate") sets = 4;
  if (experience === "advanced") sets = 5;
  if (intensity_pref === "low") sets -= 1;
  if (sets < 2) sets = 2;
  return sets;
}

function suggestReps(goal, pattern, intensity_pref, experience) {
  let reps;
  if (goal === "mass") {
    reps = pattern === "squat" || pattern === "hinge" ? "6–8" : "8–12";
  } else if (goal === "reduction") {
    reps = "10–15";
  } else {
    reps = "8–12";
  }
  if (intensity_pref === "low") {
    if (reps === "6–8") reps = "8–10";
    else reps = "10–15";
  } else if (
    intensity_pref === "high" &&
    ["squat", "hinge", "push_h", "pull_h"].includes(pattern)
  ) {
    reps = "5–8";
  }
  if (experience === "beginner" && reps === "5–8") reps = "6–8";
  return reps;
}

function generateProgressionNotes() {
  return [
    { week: 1, note: "Tydzień 1: Umiarkowana intensywność, skup się na technice i poznaniu ćwiczeń." },
    { week: 2, note: "Tydzień 2: Delikatnie zwiększ obciążenia lub liczbę powtórzeń (~5–10%)." },
    { week: 3, note: "Tydzień 3: Trenuj bliżej upadku mięśniowego w ostatnich seriach (RIR 1–2)." },
    { week: 4, note: "Tydzień 4: Deload – zmniejsz ciężary o ok. 20–30%, utrzymaj technikę i regenerację." },
  ];
}

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

// ---------------- Logika wyboru splitu ---------------- //
function pickSplit(goal, days) {
  if (days <= 2) return SPLIT_TEMPLATES.FBW_2;
  if (days === 3) {
    return (goal === "mass" || goal === "recomposition") ? SPLIT_TEMPLATES.PPL_3 : SPLIT_TEMPLATES.FBW_3;
  }
  if (days === 4) return SPLIT_TEMPLATES.ULUL_4;
  if (days === 5) {
    console.warn("[Generator] Logika dla 5 dni niezaimplementowana, używam ULUL_4.");
    return SPLIT_TEMPLATES.ULUL_4;
  }
  return SPLIT_TEMPLATES.PPL_6;
}

// ---------------- GŁÓWNA LOGIKA: Generowanie planu ---------------- //

async function fetchViableExercises(poolPromise, { patterns, location, equipmentSet, experience }) {
  // ⭐️ ZMIANA: poolPromise jest teraz przekazywany jako argument
  const equipmentPlaceholders = Array.from(equipmentSet).map(() => "?").join(" OR ");
  const sql = `
    SELECT 
      code, name, primary_muscle, pattern, equipment, difficulty, minutes_est,
      description, video_url
    FROM exercises
    WHERE pattern IN (?)
      AND FIND_IN_SET(?, location)
      AND (${equipmentPlaceholders.replace(/\?/g, (eq) => `FIND_IN_SET(?, equipment)`)})
      AND difficulty <= ?
  `;
  let maxDifficulty;
  if (experience === "beginner") maxDifficulty = 3;
  else if (experience === "intermediate") maxDifficulty = 4;
  else maxDifficulty = 5; 
  const params = [patterns, location, ...equipmentSet, maxDifficulty];
  try {
    const [rows] = await poolPromise.query(sql, params); // ⭐️ Używamy przekazanego poolPromise
    return rows;
  } catch (err) {
    console.error("Błąd SQL w fetchViableExercises:", err);
    throw new Error("Błąd pobierania ćwiczeń z bazy danych.");
  }
}

function selectExerciseSet(viableExercises, {
  criteria,
  answers,
  avoidCodes = new Set(),
}) {
  const { maxMinutes, minExercises, maxExercises, muscleBias } = criteria;
  const { experience, goal, intensity_pref } = answers;

  let filtered = viableExercises.filter(ex => !avoidCodes.has(ex.code));
  
  if (filtered.length < minExercises && viableExercises.length > 0) {
    console.warn(`[Generator] Za mało unikalnych ćwiczeń, resetuję avoidCodes.`);
    filtered = viableExercises;
  }

  const biasSet = new Set(muscleBias || []);
  filtered.sort((a, b) => {
    const aBias = biasSet.has(a.primary_muscle) ? 0 : 1;
    const bBias = biasSet.has(b.primary_muscle) ? 0 : 1;
    if (aBias !== bBias) return aBias - bBias;
    if (experience === "advanced") {
      return b.difficulty - a.difficulty;
    }
    return a.difficulty - b.difficulty;
  });

  const picked = [];
  let totalMinutes = 0;
  const patternsUsed = new Set();

  for (const ex of filtered) {
    const estMin = ex.minutes_est || 6;
    if (totalMinutes + estMin > maxMinutes && picked.length >= minExercises) {
      break;
    }
    if (picked.length >= maxExercises) {
      break;
    }
    if (ex.pattern !== 'accessory' && patternsUsed.has(ex.pattern)) {
      continue;
    }
    picked.push(ex);
    totalMinutes += estMin;
    patternsUsed.add(ex.pattern);
    avoidCodes.add(ex.code);
    const alts = ALTERNATIVES_MAP.get(ex.code);
    if (alts) {
      alts.forEach(altCode => avoidCodes.add(altCode));
    }
  }

  const sets = baseSets(experience, intensity_pref);
  return picked.map((ex) => ({
    code: ex.code,
    name: ex.name,
    sets,
    reps: suggestReps(goal, ex.pattern, intensity_pref, experience),
    description: ex.description, // <-- POPRAWKA 2: Dodano brakujące pole
    video_url: ex.video_url,   // <-- POPRAWKA 2: Dodano brakujące pole
    weight: '' // Dodajemy puste pole na wagę
  }));
}

async function generateWeekFromDb(poolPromise, splitTemplate, answers) {
  const { location, experience, session_time } = answers;
  const equipmentSet = new Set([
    ...(answers.equipment || []),
    "bodyweight",
    "none",
  ]);

  let muscleBias = [];
  if (answers.focus_body === "upper") {
    muscleBias = ["chest", "lats", "mid-back", "shoulders", "biceps", "triceps"];
  } else if (answers.focus_body === "lower") {
    muscleBias = ["quads", "hamstrings", "glutes", "core", "calves"];
  }

  const weekPlan = [];
  const maxMinPerSession = session_time || 60;
  const avoidCodes = new Set();
  const allPatterns = new Set();

  Object.values(splitTemplate.blocks).forEach(block => {
    block.patterns.forEach(p => allPatterns.add(p));
  });

  const allViableExercises = await fetchViableExercises(poolPromise, {
    patterns: Array.from(allPatterns),
    location,
    equipmentSet,
    experience,
  });

  for (let i = 0; i < splitTemplate.schedule.length; i++) {
    const blockName = splitTemplate.schedule[i];
    const dayLabel = splitTemplate.days[i] || `Dzień ${i + 1}`;
    const blockDef = splitTemplate.blocks[blockName];
    
    const viableForBlock = allViableExercises.filter(ex => 
      blockDef.patterns.includes(ex.pattern)
    );

    const criteria = {
      maxMinutes: maxMinPerSession,
      minExercises: blockDef.min_ex || 3,
      maxExercises: blockDef.max_ex || 5,
      muscleBias: muscleBias,
    };

    const exercises = selectExerciseSet(viableForBlock, {
      criteria,
      answers,
      avoidCodes,
    });

    weekPlan.push({ day: dayLabel, block: blockName, exercises: exercises });
  }

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
      return res.status(400).json({ error: "Validation failed", details: errors });
    }

    const poolPromise = pool.promise();

    const [qResult] = await poolPromise.query(
      "INSERT INTO questionnaires (user_id, answers_json, created_at) VALUES (?, ?, NOW())",
      [userId, JSON.stringify(answers)]
    );
    const questionnaireId = qResult.insertId;

    const splitTemplate = pickSplit(answers.goal, answers.days_per_week);
    const week = await generateWeekFromDb(pool, splitTemplate, answers);
    const progression = generateProgressionNotes();

    const plan = { 
      split: splitTemplate.name,
      week, 
      progression 
    };

    const [pResult] = await poolPromise.query(
      "INSERT INTO plans (user_id, source_questionnaire_id, plan_json, created_at) VALUES (?, ?, ?, NOW())",
      [userId, questionnaireId, JSON.stringify(plan)]
    );

    res.json({
      profile: profileSummary(answers),
      plan,
      ids: { questionnaireId, planId: pResult.insertId },
    });
  } catch (error) {
    console.error("Błąd w submitAnswers:", error);
    res.status(500).json({ error: "Generowanie planu nie powiodło się." });
  }
};

// 3. Zwraca ostatnio wygenerowany plan
exports.getLatestPlan = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ error: "Unauthorized" });

    const poolPromise = pool.promise();
    const [rows] = await poolPromise.query(
      "SELECT plan_json FROM plans WHERE user_id=? ORDER BY id DESC LIMIT 1",
      [userId]
    );
    if (!rows.length) return res.json({});

    const raw = rows[0].plan_json;
    const latestPlan = typeof raw === "string" ? JSON.parse(raw) : (raw || {});

    // Upewnij się, że ćwiczenia mają pole 'weight', jeśli go brakuje
    if (latestPlan.week && Array.isArray(latestPlan.week)) {
      for (const day of latestPlan.week) {
        if (day.exercises && Array.isArray(day.exercises)) {
          for (const ex of day.exercises) {
            if (ex.weight === undefined) {
              ex.weight = '';
            }
          }
        }
      }
    }

    return res.json(latestPlan);
  } catch (error) {
    console.error("Błąd w getLatestPlan:", error);
    res.status(500).json({ error: "Pobieranie ostatniego planu nie powiodło się." });
  }
};

// 4. Tylko zapisuje odpowiedzi (bez generowania planu)
exports.saveAnswers = async (req, res) => {
  try {
    const answers = req.body || {};
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ error: "Unauthorized" });

    const poolPromise = pool.promise();
    const [qResult] = await poolPromise.query(
      "INSERT INTO questionnaires (user_id, answers_json, created_at) VALUES (?, ?, NOW())",
      [userId, JSON.stringify(answers)]
    );
    return res.json({ ok: true, questionnaireId: qResult.insertId });
  } catch (error) {
    console.error("Błąd w saveAnswers:", error);
    res.status(500).json({ error: "Zapisywanie odpowiedzi nie powiodło się." });
  }
};

// 5. Zwraca ostatnie odpowiedzi ankiety (do wypełnienia formularza)
exports.getLatestAnswers = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ error: "Unauthorized" });

    const poolPromise = pool.promise();
    const [rows] = await poolPromise.query(
      "SELECT answers_json FROM questionnaires WHERE user_id=? ORDER BY id DESC LIMIT 1",
      [userId]
    );

    let latestAnswers = {};
    if (rows.length) {
      const raw = rows[0].answers_json;
      latestAnswers = typeof raw === "string" ? JSON.parse(raw) : (raw || {});
    }

    res.json(latestAnswers);
  } catch (error) {
    console.error("Błąd w getLatestAnswers:", error);
    res.status(500).json({ error: "Pobieranie ostatnich odpowiedzi nie powiodło się." });
  }
};