const fs = require("fs");
const path = require("path");

// ---------------- 1. Ładowanie Alternatyw ---------------- //
let ALTERNATIVES_MAP = new Map();

function loadAlternatives() {
  try {
    const altPath = path.join(__dirname, "..", "data", "exercise_alternatives.json");
    if (fs.existsSync(altPath)) {
      const altData = fs.readFileSync(altPath, "utf8");
      const pairs = JSON.parse(altData);
      const map = new Map();

      for (const pairList of pairs) {
        for (const exerciseCode of pairList) {
          if (!map.has(exerciseCode)) map.set(exerciseCode, new Set());
          const alternatives = map.get(exerciseCode);
          for (const altCode of pairList) {
            if (exerciseCode !== altCode) alternatives.add(altCode);
          }
        }
      }
      ALTERNATIVES_MAP = map;
      console.log(`[Algorithm] Załadowano alternatywy dla ${map.size} ćwiczeń.`);
    }
  } catch (err) {
    console.error("[Algorithm] Błąd ładowania alternatyw:", err.message);
  }
}
// Inicjalizacja przy starcie
loadAlternatives();

// ---------------- 2. Konfiguracja (Pytania i Szablony) ---------------- //
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
    id: "injuries",
    type: "multi",
    label: "Czy posiadasz kontuzje lub bóle?",
    options: [
      { value: "none", label: "Brak" },
      { value: "knees", label: "Kolana" },
      { value: "shoulders", label: "Barki" },
      { value: "lower_back", label: "Dolny odcinek pleców" },
    ],
  },
  { id: "days_per_week", type: "number", label: "Dni w tygodniu", min: 2, max: 7 },
  { id: "session_time", type: "number", label: "Minuty na sesję", min: 20, max: 120 },
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

// ---------------- 3. Helpery Walidacji ---------------- //
function validateAnswers(a) {
  const errors = [];
  if (!a.goal) errors.push("Missing goal");
  if (!a.days_per_week) errors.push("Missing days");
  return errors;
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

// ---------------- 4. Główny Algorytm (Logic Core) ---------------- //

function generateAdvancedPlan(userProfile, allExercises, historyMap = {}) {
  const { experience, daysPerWeek, injuries, equipment, goal, location } = userProfile;

  // A. HARD FILTERING
  const validExercises = allExercises.filter(ex => {
    // 1. Kontuzje
    if (ex.excluded_injuries && Array.isArray(ex.excluded_injuries)) {
      if (ex.excluded_injuries.some(inj => injuries.includes(inj))) return false;
    }
    // 2. Lokalizacja
    if (ex.location && Array.isArray(ex.location)) {
      if (!ex.location.includes(location)) return false;
    }
    // 3. Sprzęt
    if (ex.equipment && Array.isArray(ex.equipment)) {
      const required = ex.equipment;
      // Jeśli wymagane jest 'none' lub 'bodyweight', zawsze OK
      if (required.includes('bodyweight') || required.includes('none')) return true;
      // Sprawdź czy user ma cokolwiek z wymaganych
      const hasGear = required.some(reqItem => equipment.includes(reqItem));
      if (!hasGear) return false;
    }
    return true;
  });

  if (validExercises.length === 0) return null;

  // B. WYBÓR STRUKTURY
  const splitTemplate = pickSplit(goal, daysPerWeek);

  // C. WYPEŁNIANIE SLOTÓW
  const weekPlan = [];
  const usedCodes = new Set(); // Unikalność w ramach tygodnia

  for (let i = 0; i < splitTemplate.schedule.length; i++) {
    const blockName = splitTemplate.schedule[i];
    const dayLabel = splitTemplate.days[i] || `Dzień ${i + 1}`;
    const blockDef = splitTemplate.blocks[blockName];
    
    // Filtrujemy ćwiczenia pasujące do wzorców tego bloku
    const viableForBlock = validExercises.filter(ex => blockDef.patterns.includes(ex.pattern));

    // Dobieramy ćwiczenia
    const selectedExercises = [];
    const patternsInDay = new Set();

    // Sortowanie kandydatów (Score System)
    viableForBlock.sort((a, b) => {
        return calculateScore(b, experience, goal) - calculateScore(a, experience, goal);
    });

    for (const ex of viableForBlock) {
        if (selectedExercises.length >= blockDef.max_ex) break;
        if (usedCodes.has(ex.code)) continue; // Unikaj powtórzeń w tygodniu (chyba że to core/accessory)
        if (patternsInDay.has(ex.pattern) && ex.pattern !== 'accessory' && ex.pattern !== 'core') continue; // Jeden główny wzorzec na trening

        // Dodaj
        selectedExercises.push(configureVolume(ex, experience, goal, historyMap));
        usedCodes.add(ex.code);
        patternsInDay.add(ex.pattern);
        
        // Zablokuj alternatywy
        const alts = ALTERNATIVES_MAP.get(ex.code);
        if (alts) alts.forEach(alt => usedCodes.add(alt));
    }

    // Fallback jeśli za mało ćwiczeń
    if (selectedExercises.length < blockDef.min_ex) {
        // Tu można dodać logikę fallback (np. plank), na razie zostawiamy co jest
    }

    weekPlan.push({ day: dayLabel, block: blockName, exercises: selectedExercises });
  }

  return {
    split: splitTemplate.name,
    week: weekPlan,
    progression: generateProgressionModel(experience)
  };
}

function calculateScore(ex, level, goal) {
    let score = 50;
    // Poziom
    if (level === 'beginner') {
        if (ex.difficulty <= 2) score += 30;
        if (ex.mechanics === 'isolation') score -= 10;
    } else {
        if (ex.difficulty >= 3) score += 20;
    }
    // Cel
    if (goal === 'mass' && ex.mechanics === 'compound') score += 15;
    return score + Math.random() * 5; // Shuffle
}

function configureVolume(ex, level, goal, historyMap) {
    let sets = 3;
    let reps = "8-12";
    
    // Progresja ciężaru
    let suggestedWeight = '';
    if (historyMap && historyMap[ex.code]) {
        const lastMax = parseFloat(historyMap[ex.code]);
        if (!isNaN(lastMax) && lastMax > 0) {
            const prog = lastMax * 1.025; // +2.5%
            suggestedWeight = (Math.round(prog * 2) / 2).toFixed(1);
        }
    }

    if (level === 'beginner') {
        reps = "10-12";
    } else {
        if (ex.mechanics === 'compound') { sets = 4; reps = "6-8"; }
    }

    return {
        code: ex.code,
        name: ex.name,
        sets,
        reps,
        weight: suggestedWeight,
        description: ex.description,
        video_url: ex.video_url
    };
}

function generateProgressionModel(level) {
    return [
        { week: 1, note: "Tydzień 1: Adaptacja. Zostaw 2-3 powtórzenia w zapasie." },
        { week: 2, note: "Tydzień 2: Zwiększ ciężar o 2.5% w głównych bojach." },
        { week: 3, note: "Tydzień 3: Zwiększ intensywność (RIR 1)." },
        { week: 4, note: "Tydzień 4: Deload (50% objętości)." }
    ];
}

module.exports = {
    QUESTIONS,
    validateAnswers,
    generateAdvancedPlan,
    helpers: {
        validateAnswers,
        pickSplit,
        configureVolume
    }
};