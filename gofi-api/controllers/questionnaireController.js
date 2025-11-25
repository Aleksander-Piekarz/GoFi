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
  // --- Pytanie o kontuzje (Kluczowe dla algorytmu wykluczeń) ---
  {
    id: "injuries",
    type: "multi",
    label: "Czy posiadasz kontuzje lub bóle?",
    options: [
      { value: "none", label: "Brak" },
      { value: "knees", label: "Kolana (unikanie przeciążeń nóg)" },
      { value: "shoulders", label: "Barki (unikanie wyciskania nad głowę)" },
      { value: "lower_back", label: "Dolny odcinek pleców (unikanie martwych ciągów)" },
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

// ---------------- Logika pomocnicza ---------------- //

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
  
  // Walidacja pola injuries (może być undefined, ale jak jest, musi być tablicą)
  if (a.injuries && !Array.isArray(a.injuries)) {
    errors.push("Injuries must be an array");
  }

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
    { week: 2, note: "Tydzień 2: Zwiększ ciężar o ok. 2.5-5% w głównych bojach jeśli technika była dobra." },
    { week: 3, note: "Tydzień 3: Trenuj bliżej upadku mięśniowego w ostatnich seriach (RIR 1-2)." },
    { week: 4, note: "Tydzień 4: Deload – zmniejsz objętość o połowę, aby zregenerować układ nerwowy." },
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
    injuries: answers.injuries || [],
  };
}

function pickSplit(goal, days) {
  if (days <= 2) return SPLIT_TEMPLATES.FBW_2;
  if (days === 3) {
    return (goal === "mass" || goal === "recomposition") ? SPLIT_TEMPLATES.PPL_3 : SPLIT_TEMPLATES.FBW_3;
  }
  if (days === 4) return SPLIT_TEMPLATES.ULUL_4;
  if (days === 5) return SPLIT_TEMPLATES.ULUL_4; 
  return SPLIT_TEMPLATES.PPL_6;
}

// --- NOWOŚĆ: Helper do pobierania maxów użytkownika ---
async function getUserMaxWeights(poolPromise, userId) {
  try {
    // Pobieramy maksymalny ciężar jaki użytkownik kiedykolwiek podniósł w danym ćwiczeniu
    const [rows] = await poolPromise.query(`
      SELECT exercise_code, MAX(weight) as max_weight
      FROM workout_log_sets
      WHERE user_id = ?
      GROUP BY exercise_code
    `, [userId]);
    
    const historyMap = {};
    rows.forEach(row => {
      historyMap[row.exercise_code] = row.max_weight;
    });
    return historyMap;
  } catch (e) {
    console.error("Błąd pobierania historii wag:", e);
    return {};
  }
}

// ---------------- GŁÓWNA LOGIKA ---------------- //

async function fetchViableExercises(poolPromise, { patterns, location, equipmentSet, experience }) {
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
    const [rows] = await poolPromise.query(sql, params);
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
  historyMap = {} // --- NOWOŚĆ: Przekazujemy historię
}) {
  const { maxMinutes, minExercises, maxExercises, muscleBias } = criteria;
  const { experience, goal, intensity_pref, injuries } = answers;

  let filtered = viableExercises.filter(ex => !avoidCodes.has(ex.code));

  // --- NOWOŚĆ: ALGORYTM FILTROWANIA KONTUZJI ---
  if (injuries && Array.isArray(injuries) && !injuries.includes('none')) {
    filtered = filtered.filter(ex => {
      // 1. Kontuzja Barków: Unikamy wyciskania nad głowę (push_v) i ćwiczeń mocno angażujących barki jako primary
      if (injuries.includes('shoulders')) {
        if (ex.pattern === 'push_v') return false; 
        if (ex.primary_muscle === 'shoulders' && ex.difficulty > 2) return false; // Oszczędzamy trudne ćwiczenia na barki
      }
      // 2. Kontuzja Kolan: Unikamy ciężkich przysiadów i wykroków
      if (injuries.includes('knees')) {
        if (['squat', 'lunge'].includes(ex.pattern)) {
          // Zostawiamy ewentualnie maszyny, które są stabilniejsze, wyrzucamy wolne ciężary
          if (!ex.equipment.includes('machines') && !ex.equipment.includes('bodyweight')) return false;
        }
      }
      // 3. Kontuzja Pleców: Unikamy Hinge (martwe ciągi) i wiosłowania w opadzie (duże siły ścinające)
      if (injuries.includes('lower_back')) {
        if (ex.pattern === 'hinge') return false;
        if (ex.code === 'BENT_OVER_ROW_BB' || ex.code === 'PENDLAY_ROW') return false;
      }
      return true;
    });
  }

  // Reset avoidCodes jeśli filtracja zbyt agresywna
  if (filtered.length < minExercises && viableExercises.length > 0) {
    console.warn(`[Generator] Za mało ćwiczeń po filtracji (kontuzje/unikalność). Resetuję avoidCodes.`);
    // W przypadku kontuzji, lepiej zwrócić mniej ćwiczeń niż niebezpieczne, więc resetujemy tylko 'avoidCodes' a nie filtr kontuzji
    // Tutaj uproszczenie: bierzemy z powrotem wszystko co pasuje do kontuzji
    filtered = viableExercises.filter(ex => {
       // (Powtórzona logika filtracji kontuzji - w produkcji warto wydzielić do funkcji)
       if (injuries && injuries.includes('shoulders') && ex.pattern === 'push_v') return false;
       if (injuries && injuries.includes('knees') && ['squat', 'lunge'].includes(ex.pattern) && !ex.equipment.includes('machines')) return false;
       if (injuries && injuries.includes('lower_back') && ex.pattern === 'hinge') return false;
       return true;
    });
  }

  const biasSet = new Set(muscleBias || []);
  filtered.sort((a, b) => {
    const aBias = biasSet.has(a.primary_muscle) ? 0 : 1;
    const bBias = biasSet.has(b.primary_muscle) ? 0 : 1;
    if (aBias !== bBias) return aBias - bBias;
    if (experience === "advanced") return b.difficulty - a.difficulty;
    return a.difficulty - b.difficulty;
  });

  const picked = [];
  let totalMinutes = 0;
  const patternsUsed = new Set();

  for (const ex of filtered) {
    const estMin = ex.minutes_est || 6;
    if (totalMinutes + estMin > maxMinutes && picked.length >= minExercises) break;
    if (picked.length >= maxExercises) break;
    if (ex.pattern !== 'accessory' && patternsUsed.has(ex.pattern)) continue;
    
    picked.push(ex);
    totalMinutes += estMin;
    patternsUsed.add(ex.pattern);
    avoidCodes.add(ex.code);
    
    const alts = ALTERNATIVES_MAP.get(ex.code);
    if (alts) alts.forEach(altCode => avoidCodes.add(altCode));
  }

  const sets = baseSets(experience, intensity_pref);
  
  return picked.map((ex) => {
    // --- NOWOŚĆ: ALGORYTM PROGRESJI ---
    // Jeśli mamy historię dla tego ćwiczenia, sugerujemy ciężar +2.5% (zaokrąglone do 0.5)
    let suggestedWeight = '';
    if (historyMap[ex.code]) {
      const lastMax = parseFloat(historyMap[ex.code]);
      if (!isNaN(lastMax) && lastMax > 0) {
        // Progressive overload: +2.5%
        const prog = lastMax * 1.025;
        // Zaokrąglenie do 0.5 kg
        const rounded = (Math.round(prog * 2) / 2).toFixed(1);
        suggestedWeight = rounded.toString();
      }
    }

    return {
      code: ex.code,
      name: ex.name,
      sets,
      reps: suggestReps(goal, ex.pattern, intensity_pref, experience),
      description: ex.description,
      video_url: ex.video_url,
      weight: suggestedWeight // <-- Tutaj wstawiamy wynik algorytmu
    };
  });
}

async function generateWeekFromDb(poolPromise, splitTemplate, answers, historyMap) {
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
      historyMap, // Przekazujemy mapę historii
    });

    weekPlan.push({ day: dayLabel, block: blockName, exercises: exercises });
  }

  return weekPlan;
}

// ---------------- ROUTES ---------------- //

exports.getQuestions = async (_req, res) => {
  res.json(QUESTIONS);
};

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

    // 1. Zapis ankiety
    const [qResult] = await poolPromise.query(
      "INSERT INTO questionnaires (user_id, answers_json, created_at) VALUES (?, ?, NOW())",
      [userId, JSON.stringify(answers)]
    );
    const questionnaireId = qResult.insertId;

    // --- NOWOŚĆ: Pobranie historii do algorytmu ---
    const historyMap = await getUserMaxWeights(poolPromise, userId);

    // 2. Generowanie planu z uwzględnieniem historii
    const splitTemplate = pickSplit(answers.goal, answers.days_per_week);
    const week = await generateWeekFromDb(poolPromise, splitTemplate, answers, historyMap);
    const progression = generateProgressionNotes();

    const plan = { 
      split: splitTemplate.name,
      week, 
      progression 
    };

    // 3. Zapis planu
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

exports.helpers = {
  validateAnswers,
  pickSplit,
  baseSets,
  suggestReps
};