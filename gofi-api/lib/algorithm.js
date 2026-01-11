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
  // === SEKCJA 1: PODSTAWOWE INFORMACJE ===
  {
    id: "section_basics",
    type: "header",
    label: "📋 Podstawowe informacje",
    description: "Pomóż nam lepiej poznać Twój profil treningowy"
  },
  {
    id: "goal",
    type: "single",
    label: "Jaki jest Twój główny cel?",
    icon: "🎯",
    options: [
      { value: "reduction", label: "🔥 Redukcja tkanki tłuszczowej", description: "Schudnąć zachowując mięśnie" },
      { value: "mass", label: "💪 Budowa masy mięśniowej", description: "Przyrost siły i mięśni" },
      { value: "recomposition", label: "⚖️ Rekompozycja", description: "Spalanie tłuszczu + budowa mięśni" },
      { value: "strength", label: "🏋️ Siła", description: "Maksymalna siła w głównych bojach" },
      { value: "endurance", label: "🏃 Wytrzymałość", description: "Lepsze wyniki cardio + siła" },
    ],
  },
  {
    id: "experience",
    type: "single",
    label: "Jakie jest Twoje doświadczenie treningowe?",
    icon: "📊",
    options: [
      { value: "beginner", label: "🌱 Początkujący", description: "0-6 miesięcy regularnego treningu" },
      { value: "intermediate", label: "📈 Średnio-zaawansowany", description: "6 miesięcy - 2 lata" },
      { value: "advanced", label: "🏆 Zaawansowany", description: "Ponad 2 lata regularnych treningów" },
    ],
  },
  {
    id: "age_range",
    type: "single",
    label: "Twój przedział wiekowy",
    icon: "🎂",
    options: [
      { value: "18-25", label: "18-25 lat" },
      { value: "26-35", label: "26-35 lat" },
      { value: "36-45", label: "36-45 lat" },
      { value: "46-55", label: "46-55 lat" },
      { value: "55+", label: "55+ lat" },
    ],
  },
  {
    id: "gender",
    type: "single",
    label: "Płeć",
    icon: "👤",
    optional: true,
    options: [
      { value: "male", label: "Mężczyzna" },
      { value: "female", label: "Kobieta" },
      { value: "other", label: "Wolę nie podawać" },
    ],
  },

  // === SEKCJA 2: HARMONOGRAM ===
  {
    id: "section_schedule",
    type: "header",
    label: "📅 Harmonogram treningów",
    description: "Dostosujemy plan do Twojego rytmu życia"
  },
  { 
    id: "days_per_week", 
    type: "number", 
    label: "Ile dni w tygodniu możesz trenować?", 
    icon: "📆",
    min: 2, 
    max: 7,
    hint: "Optymalna częstotliwość to 3-5 dni"
  },
  { 
    id: "session_time", 
    type: "number", 
    label: "Ile minut trwa Twoja sesja treningowa?", 
    icon: "⏱️",
    min: 20, 
    max: 120,
    hint: "Wlicz rozgrzewkę i stretching"
  },
  {
    id: "preferred_days",
    type: "multi",
    label: "Które dni preferujesz na trening?",
    icon: "🗓️",
    optional: true,
    options: [
      { value: "mon", label: "Pon" },
      { value: "tue", label: "Wt" },
      { value: "wed", label: "Śr" },
      { value: "thu", label: "Czw" },
      { value: "fri", label: "Pt" },
      { value: "sat", label: "Sob" },
      { value: "sun", label: "Ndz" },
    ],
  },

  // === SEKCJA 3: MIEJSCE I SPRZĘT ===
  {
    id: "section_equipment",
    type: "header",
    label: "🏠 Miejsce i sprzęt",
    description: "Dobierzemy ćwiczenia do Twoich możliwości"
  },
  {
    id: "location",
    type: "single",
    label: "Gdzie głównie ćwiczysz?",
    icon: "📍",
    options: [
      { value: "gym", label: "🏢 Siłownia", description: "Pełne wyposażenie" },
      { value: "home", label: "🏠 Dom", description: "Ograniczony sprzęt" },
      { value: "outdoor", label: "🌳 Na zewnątrz", description: "Parki, boiska" },
    ],
  },
  {
    id: "equipment",
    type: "multi",
    label: "Jaki sprzęt masz do dyspozycji?",
    icon: "🏋️",
    showIf: { location: ["home", "gym", "outdoor"] },
    options: [
      { value: "none", label: "Brak (kalistenika)" },
      { value: "dumbbells", label: "Hantle" },
      { value: "barbell", label: "Sztanga + obciążenia" },
      { value: "kettlebell", label: "Kettlebell" },
      { value: "bands", label: "Gumy oporowe" },
      { value: "pullup_bar", label: "Drążek do podciągania" },
      { value: "bench", label: "Ławka" },
      { value: "rack", label: "Stojaki/Rack" },
      { value: "machines", label: "Maszyny" },
      { value: "cables", label: "Wyciągi" },
    ],
  },

  // === SEKCJA 4: ZDROWIE I OGRANICZENIA ===
  {
    id: "section_health",
    type: "header",
    label: "🩺 Zdrowie i ograniczenia",
    description: "Twoje bezpieczeństwo jest priorytetem"
  },
  {
    id: "injuries",
    type: "multi",
    label: "Czy masz kontuzje lub obszary wymagające ostrożności?",
    icon: "⚠️",
    options: [
      { value: "none", label: "✅ Brak ograniczeń" },
      { value: "knees", label: "🦵 Kolana" },
      { value: "shoulders", label: "💪 Barki" },
      { value: "lower_back", label: "🔙 Dolny odcinek pleców" },
      { value: "upper_back", label: "⬆️ Górna część pleców/kark" },
      { value: "wrists", label: "✋ Nadgarstki" },
      { value: "elbows", label: "💪 Łokcie" },
      { value: "hips", label: "🦴 Biodra" },
      { value: "ankles", label: "🦶 Kostki" },
    ],
  },
  {
    id: "mobility_issues",
    type: "multi",
    label: "Czy masz problemy z mobilnością?",
    icon: "🧘",
    optional: true,
    options: [
      { value: "none", label: "✅ Brak problemów" },
      { value: "hip_flexors", label: "Napięte biodra" },
      { value: "hamstrings", label: "Sztywne dwugłowe" },
      { value: "thoracic", label: "Ograniczona mobilność kręgosłupa piersiowego" },
      { value: "ankles", label: "Ograniczona dorsifleksja kostek" },
    ],
  },

  // === SEKCJA 5: PREFERENCJE TRENINGOWE ===
  {
    id: "section_preferences",
    type: "header",
    label: "⚡ Preferencje treningowe",
    description: "Spersonalizuj swój trening"
  },
  {
    id: "focus_body",
    type: "single",
    label: "Na jakich partiach chcesz się skupić?",
    icon: "🎯",
    options: [
      { value: "balanced", label: "⚖️ Całe ciało równomiernie" },
      { value: "upper", label: "💪 Akcent na górę ciała" },
      { value: "lower", label: "🦵 Akcent na dół ciała" },
      { value: "core", label: "🎯 Akcent na core/brzuch" },
    ],
  },
  {
    id: "training_style",
    type: "single",
    label: "Jaki styl treningu preferujesz?",
    icon: "🔥",
    optional: true,
    options: [
      { value: "traditional", label: "Tradycyjny (serie/powtórzenia)" },
      { value: "circuit", label: "Obwodowy (circuit training)" },
      { value: "supersets", label: "Superserie" },
      { value: "mixed", label: "Zmieszany" },
    ],
  },
  {
    id: "cardio_preference",
    type: "single",
    label: "Czy chcesz włączyć cardio do planu?",
    icon: "🏃",
    optional: true,
    options: [
      { value: "none", label: "❌ Nie, tylko siłówka" },
      { value: "light", label: "🚶 Lekkie (spacery, rower)" },
      { value: "moderate", label: "🏃 Umiarkowane (2-3x tydzień)" },
      { value: "hiit", label: "🔥 HIIT (intensywne interwały)" },
    ],
  },
  {
    id: "weak_points",
    type: "multi",
    label: "Jakie partie ciała uważasz za słabe punkty?",
    icon: "📉",
    optional: true,
    options: [
      { value: "none", label: "Brak - wszystko równo" },
      { value: "chest", label: "Klatka piersiowa" },
      { value: "back", label: "Plecy" },
      { value: "shoulders", label: "Barki" },
      { value: "arms", label: "Ramiona (biceps/triceps)" },
      { value: "legs", label: "Nogi" },
      { value: "glutes", label: "Pośladki" },
      { value: "core", label: "Core/Brzuch" },
      { value: "calves", label: "Łydki" },
    ],
  },
];

// ============================================
// STANDARDY SIŁOWNI - REKOMENDACJE OBJĘTOŚCIOWE
// ============================================
// Zgodnie z badaniami (Schoenfeld et al.) i standardami NSCA:
// - Początkujący: 3-4 ćwiczenia/trening, 2-3 serie/ćwiczenie
// - Średniozaawansowani: 4-5 ćwiczeń/trening, 3-4 serie/ćwiczenie
// - Zaawansowani: 5-6 ćwiczeń/trening, 4-5 serii/ćwiczenie
// - Czas treningu: 45-75 minut (bez rozgrzewki)
// - Optymalna częstotliwość: 2x/tydzień na grupę mięśniową
// ============================================

const SPLIT_TEMPLATES = {
  FBW_2: {
    name: "Full Body Workout (2x/week)",
    schedule: ["A", "B"],
    days: ["Mon", "Thu"],
    blocks: {
      // 2x/tydz = więcej ćwiczeń na sesję, pełne pokrycie ciała
      A: { 
        patterns: ["squat", "push_h", "pull_h", "hinge", "push_v", "core"], 
        min_ex: 5, max_ex: 6,
        recommended: ["squat", "push_h", "pull_h", "accessory", "core"]
      },
      B: { 
        patterns: ["hinge", "push_v", "pull_v", "squat", "push_h", "core"], 
        min_ex: 5, max_ex: 6,
        recommended: ["hinge", "push_v", "pull_v", "accessory", "core"]
      },
    },
  },
  FBW_3: {
    name: "Full Body Workout (3x/week)",
    schedule: ["A", "B", "C"],
    days: ["Mon", "Wed", "Fri"],
    blocks: {
      A: { 
        patterns: ["squat", "push_h", "pull_h", "accessory", "core"], 
        min_ex: 4, max_ex: 5 
      },
      B: { 
        patterns: ["hinge", "push_v", "pull_v", "accessory", "core"], 
        min_ex: 4, max_ex: 5 
      },
      C: { 
        patterns: ["lunge", "push_h", "pull_h", "accessory", "core"], 
        min_ex: 4, max_ex: 5 
      },
    },
  },
  FBW_4: {
    name: "Full Body Workout (4x/week)",
    schedule: ["A", "B", "C", "D"],
    days: ["Mon", "Tue", "Thu", "Fri"],
    blocks: {
      A: { patterns: ["squat", "push_h", "pull_h", "core"], min_ex: 4, max_ex: 5 },
      B: { patterns: ["hinge", "push_v", "pull_v", "accessory"], min_ex: 4, max_ex: 5 },
      C: { patterns: ["lunge", "push_h", "pull_h", "core"], min_ex: 4, max_ex: 5 },
      D: { patterns: ["squat", "push_v", "pull_v", "accessory"], min_ex: 4, max_ex: 5 },
    },
  },
  ULUL_4: {
    name: "Upper/Lower (4x/week)",
    schedule: ["Upper A", "Lower A", "Upper B", "Lower B"],
    days: ["Mon", "Tue", "Thu", "Fri"],
    blocks: {
      // Upper: 2 push + 2 pull + 1-2 akcesoria (barki/ramiona)
      "Upper A": { 
        patterns: ["push_h", "pull_h", "push_v", "pull_v", "accessory"], 
        min_ex: 5, max_ex: 6 
      },
      // Lower: squat/hinge/lunge + core + łydki
      "Lower A": { 
        patterns: ["squat", "hinge", "lunge", "accessory", "core"], 
        min_ex: 4, max_ex: 5 
      },
      "Upper B": { 
        patterns: ["pull_v", "push_h", "pull_h", "push_v", "accessory"], 
        min_ex: 5, max_ex: 6 
      },
      "Lower B": { 
        patterns: ["hinge", "squat", "lunge", "accessory", "core"], 
        min_ex: 4, max_ex: 5 
      },
    },
  },
  PPL_3: {
    name: "Push/Pull/Legs (3x/week)",
    schedule: ["Push", "Pull", "Legs"],
    days: ["Mon", "Wed", "Fri"],
    blocks: {
      // Push: klatka + barki + triceps (5-6 ćw dla pełnego pokrycia)
      Push: { 
        patterns: ["push_h", "push_v", "accessory"], 
        min_ex: 5, max_ex: 6 
      },
      // Pull: plecy + biceps + tylne barki (5-6 ćw)
      Pull: { 
        patterns: ["pull_h", "pull_v", "accessory"], 
        min_ex: 5, max_ex: 6 
      },
      // Legs: quads + hamstrings + glutes + calves + core
      Legs: { 
        patterns: ["squat", "hinge", "lunge", "accessory", "core"], 
        min_ex: 5, max_ex: 6 
      },
    },
  },
  PPL_6: {
    name: "Push/Pull/Legs (6x/week)",
    schedule: ["Push A", "Pull A", "Legs A", "Push B", "Pull B", "Legs B"],
    days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
    blocks: {
      // Przy 6x/tyg można zrobić 4-5 ćw/sesję (2 sesje/grupa = dobra objętość)
      "Push A": { patterns: ["push_h", "push_v", "accessory"], min_ex: 4, max_ex: 5 },
      "Pull A": { patterns: ["pull_h", "pull_v", "accessory"], min_ex: 4, max_ex: 5 },
      "Legs A": { patterns: ["squat", "hinge", "lunge", "core"], min_ex: 4, max_ex: 5 },
      "Push B": { patterns: ["push_v", "push_h", "accessory"], min_ex: 4, max_ex: 5 },
      "Pull B": { patterns: ["pull_v", "pull_h", "accessory"], min_ex: 4, max_ex: 5 },
      "Legs B": { patterns: ["hinge", "squat", "lunge", "core"], min_ex: 4, max_ex: 5 },
    },
  },
  // Bro Split dla 5-6 dni
  BRO_5: {
    name: "Bro Split (5x/week)",
    schedule: ["Chest", "Back", "Shoulders", "Legs", "Arms"],
    days: ["Mon", "Tue", "Wed", "Fri", "Sat"],
    blocks: {
      Chest: { patterns: ["push_h", "push_v", "accessory"], min_ex: 4, max_ex: 5 },
      Back: { patterns: ["pull_h", "pull_v", "accessory"], min_ex: 4, max_ex: 5 },
      Shoulders: { patterns: ["push_v", "accessory"], min_ex: 4, max_ex: 5 },
      Legs: { patterns: ["squat", "hinge", "lunge", "core"], min_ex: 5, max_ex: 6 },
      Arms: { patterns: ["accessory"], min_ex: 5, max_ex: 6 },
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

/**
 * Dobiera optymalny split na podstawie celu i dni treningowych
 * Zgodnie z rekomendacjami NSCA i badaniami Schoenfelda
 */
function pickSplit(goal, days, experience = 'intermediate') {
  // Dla początkujących - Full Body jest najbezpieczniejszy
  if (experience === 'beginner') {
    if (days <= 2) return SPLIT_TEMPLATES.FBW_2;
    if (days <= 3) return SPLIT_TEMPLATES.FBW_3;
    return SPLIT_TEMPLATES.FBW_4;
  }
  
  // Średniozaawansowani i zaawansowani
  if (days <= 2) return SPLIT_TEMPLATES.FBW_2;
  
  if (days === 3) {
    // PPL daje lepszą objętość na grupę dla celów masowych
    if (goal === "mass" || goal === "hypertrophy") return SPLIT_TEMPLATES.PPL_3;
    return SPLIT_TEMPLATES.FBW_3;
  }
  
  if (days === 4) return SPLIT_TEMPLATES.ULUL_4;
  
  if (days === 5) {
    // 5 dni - Bro Split lub Upper/Lower z dodatkowym dniem
    if (goal === "mass" || goal === "hypertrophy") return SPLIT_TEMPLATES.BRO_5;
    return SPLIT_TEMPLATES.ULUL_4; // ULUL + 1 dzień odpoczynku
  }
  
  // 6+ dni - PPL x2 (optymalna częstotliwość 2x/tydzień na grupę)
  return SPLIT_TEMPLATES.PPL_6;
}

// ---------------- 4. Główny Algorytm (Logic Core) ---------------- //

// Helper do normalizacji nazw sprzętu
function normalizeEquipment(name) {
  if (!name) return name;
  const normalized = name.toLowerCase().trim();
  // Mapowanie różnych nazw na standardowe
  const mapping = {
    'body weight': 'bodyweight',
    'body_weight': 'bodyweight',
    'body': 'bodyweight',
    'bw': 'bodyweight',
    'nothing': 'none',
    'no equipment': 'none',
    'dumbells': 'dumbbell',
    'dumbbells': 'dumbbell',
    'barbells': 'barbell',
    'cables': 'cable',
    'machines': 'machine',
    'bands': 'band',
    'resistance band': 'band',
    'resistance bands': 'band',
    'kettlebells': 'kettlebell',
    'pull up bar': 'pull_up_bar',
    'pullup bar': 'pull_up_bar',
    'pull-up bar': 'pull_up_bar',
  };
  return mapping[normalized] || normalized;
}

// Mapowanie skrótów dni na pełne nazwy
const DAY_NAMES = {
  'mon': 'Poniedziałek',
  'tue': 'Wtorek', 
  'wed': 'Środa',
  'thu': 'Czwartek',
  'fri': 'Piątek',
  'sat': 'Sobota',
  'sun': 'Niedziela'
};

const DAY_ORDER = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/**
 * Wybiera dni treningowe na podstawie preferencji użytkownika
 * @param {number} daysNeeded - ile dni treningowych potrzeba
 * @param {string[]} preferredDays - preferowane dni (np. ['mon', 'wed', 'fri'])
 * @returns {string[]} - wybrane dni w formacie pełnym (np. ['Poniedziałek', 'Środa', 'Piątek'])
 */
function selectTrainingDays(daysNeeded, preferredDays = []) {
  // Sortuj preferowane dni wg kolejności tygodnia
  const sortedPreferred = preferredDays
    .filter(d => DAY_ORDER.includes(d))
    .sort((a, b) => DAY_ORDER.indexOf(a) - DAY_ORDER.indexOf(b));
  
  let selectedDays = [];
  
  if (sortedPreferred.length === 0) {
    // Brak preferencji - domyślny rozkład
    const defaultSpreads = {
      2: ['mon', 'thu'],
      3: ['mon', 'wed', 'fri'],
      4: ['mon', 'tue', 'thu', 'fri'],
      5: ['mon', 'tue', 'wed', 'fri', 'sat'],
      6: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'],
      7: DAY_ORDER
    };
    selectedDays = defaultSpreads[daysNeeded] || defaultSpreads[3];
  } else if (sortedPreferred.length === daysNeeded) {
    // Dokładnie tyle dni ile trzeba
    selectedDays = sortedPreferred;
  } else if (sortedPreferred.length > daysNeeded) {
    // Więcej preferowanych dni niż potrzeba - wybierz losowo z zachowaniem rozkładu
    // Preferuj dni równomiernie rozłożone w tygodniu
    selectedDays = selectSpreadDays(sortedPreferred, daysNeeded);
  } else {
    // Mniej preferowanych dni niż potrzeba - uzupełnij
    selectedDays = [...sortedPreferred];
    const remaining = DAY_ORDER.filter(d => !selectedDays.includes(d));
    
    // Dodaj brakujące dni (preferując dni z przerwami)
    while (selectedDays.length < daysNeeded && remaining.length > 0) {
      // Znajdź dzień z największą przerwą od ostatniego treningu
      let bestDay = remaining[0];
      let bestGap = 0;
      
      for (const day of remaining) {
        const dayIdx = DAY_ORDER.indexOf(day);
        let minGap = 7;
        
        for (const selected of selectedDays) {
          const selectedIdx = DAY_ORDER.indexOf(selected);
          const gap = Math.min(
            Math.abs(dayIdx - selectedIdx),
            7 - Math.abs(dayIdx - selectedIdx)
          );
          minGap = Math.min(minGap, gap);
        }
        
        if (minGap > bestGap) {
          bestGap = minGap;
          bestDay = day;
        }
      }
      
      selectedDays.push(bestDay);
      remaining.splice(remaining.indexOf(bestDay), 1);
    }
    
    // Sortuj wg kolejności tygodnia
    selectedDays.sort((a, b) => DAY_ORDER.indexOf(a) - DAY_ORDER.indexOf(b));
  }
  
  // Konwertuj na pełne nazwy
  return selectedDays.map(d => DAY_NAMES[d] || d);
}

/**
 * Wybiera dni równomiernie rozłożone z podanej listy
 */
function selectSpreadDays(days, count) {
  if (days.length <= count) return days;
  
  const result = [];
  const step = days.length / count;
  
  for (let i = 0; i < count; i++) {
    const idx = Math.round(i * step);
    if (idx < days.length && !result.includes(days[idx])) {
      result.push(days[idx]);
    }
  }
  
  // Uzupełnij jeśli brakuje
  while (result.length < count) {
    for (const day of days) {
      if (!result.includes(day)) {
        result.push(day);
        break;
      }
    }
  }
  
  return result.sort((a, b) => DAY_ORDER.indexOf(a) - DAY_ORDER.indexOf(b));
}

function generateAdvancedPlan(userProfile, allExercises, historyMap = {}) {
  const { experience, daysPerWeek, injuries, equipment, goal, location, preferredDays = [], sessionTime = 60 } = userProfile;
  
  // Normalizuj sprzęt użytkownika
  const normalizedUserEquipment = equipment.map(normalizeEquipment);

  console.log(`Generowanie planu: ${allExercises.length} ćwiczeń, lokalizacja: ${location}, sprzęt: ${normalizedUserEquipment.join(', ')}`);
  console.log(`Preferowane dni: ${preferredDays.join(', ') || 'brak'}, czas sesji: ${sessionTime} min`);

  // A. HARD FILTERING
  const validExercises = allExercises.filter(ex => {
    // 1. Kontuzje
    if (ex.excluded_injuries && Array.isArray(ex.excluded_injuries)) {
      if (ex.excluded_injuries.some(inj => injuries.includes(inj))) return false;
    }
    
    // 2. Lokalizacja - jeśli brak location w ćwiczeniu, zakładamy że pasuje wszędzie
    if (ex.location && Array.isArray(ex.location) && ex.location.length > 0) {
      if (!ex.location.includes(location)) return false;
    }
    
    // 3. Sprzęt
    if (ex.equipment && Array.isArray(ex.equipment) && ex.equipment.length > 0) {
      const normalizedRequired = ex.equipment.map(normalizeEquipment);
      
      // Jeśli wymagane jest 'none' lub 'bodyweight', zawsze OK
      if (normalizedRequired.includes('bodyweight') || normalizedRequired.includes('none')) return true;
      if (normalizedRequired.includes('body weight')) return true;
      
      // Sprawdź czy user ma cokolwiek z wymaganych
      const hasGear = normalizedRequired.some(reqItem => 
        normalizedUserEquipment.includes(normalizeEquipment(reqItem))
      );
      if (!hasGear) return false;
    }
    return true;
  });

  console.log(`Po filtrowaniu: ${validExercises.length} pasujących ćwiczeń`);

  if (validExercises.length === 0) {
    console.warn('Brak pasujących ćwiczeń! Sprawdź kryteria filtrowania.');
    return null;
  }

  // B. WYBÓR STRUKTURY - przekazujemy doświadczenie
  const splitTemplate = pickSplit(goal, daysPerWeek, experience);
  
  // C. WYBÓR DNI TRENINGOWYCH na podstawie preferencji użytkownika
  const trainingDays = selectTrainingDays(splitTemplate.schedule.length, preferredDays);
  
  console.log(`Wybrany split: ${splitTemplate.name}`);
  console.log(`Dni treningowe: ${trainingDays.join(', ')}`);

  // D. WYPEŁNIANIE SLOTÓW
  const weekPlan = [];
  const usedCodes = new Set(); // Unikalność w ramach tygodnia

  for (let i = 0; i < splitTemplate.schedule.length; i++) {
    const blockName = splitTemplate.schedule[i];
    // Użyj wybranych dni treningowych zamiast domyślnych z szablonu
    const dayLabel = trainingDays[i] || splitTemplate.days[i] || `Dzień ${i + 1}`;
    const blockDef = splitTemplate.blocks[blockName];
    
    // Filtrujemy ćwiczenia pasujące do wzorców tego bloku
    // Dodajemy też ćwiczenia typu "accessory" i "core" które pasują wszędzie
    const viableForBlock = validExercises.filter(ex => {
      if (blockDef.patterns.includes(ex.pattern)) return true;
      // Accessory i core mogą być dodane do każdego bloku
      if (ex.pattern === 'accessory' || ex.pattern === 'core') return true;
      return false;
    });

    // Dobieramy ćwiczenia
    const selectedExercises = [];
    const patternsInDay = new Set();
    const targetExercises = blockDef.max_ex; // Cel: max ćwiczeń

    // Sortowanie kandydatów (Score System)
    viableForBlock.sort((a, b) => {
        return calculateScore(b, experience, goal) - calculateScore(a, experience, goal);
    });

    // Pierwsza pętla: dobierz główne wzorce ruchu
    for (const ex of viableForBlock) {
        if (selectedExercises.length >= targetExercises) break;
        if (usedCodes.has(ex.code)) continue;
        
        // Dla głównych wzorców (nie accessory/core) - jeden na trening
        if (ex.pattern !== 'accessory' && ex.pattern !== 'core') {
          if (patternsInDay.has(ex.pattern)) continue;
        }

        selectedExercises.push(configureVolume(ex, experience, goal, historyMap));
        usedCodes.add(ex.code);
        patternsInDay.add(ex.pattern);
        
        // Zablokuj alternatywy
        const alts = ALTERNATIVES_MAP.get(ex.code);
        if (alts) alts.forEach(alt => usedCodes.add(alt));
    }

    // Druga pętla: jeśli mamy za mało ćwiczeń, dodaj więcej accessory/core
    if (selectedExercises.length < blockDef.min_ex) {
      const fillExercises = validExercises.filter(ex => 
        (ex.pattern === 'accessory' || ex.pattern === 'core') && 
        !usedCodes.has(ex.code)
      );
      
      for (const ex of fillExercises) {
        if (selectedExercises.length >= blockDef.min_ex) break;
        selectedExercises.push(configureVolume(ex, experience, goal, historyMap));
        usedCodes.add(ex.code);
      }
    }

    console.log(`${dayLabel} (${blockName}): ${selectedExercises.length} ćwiczeń`);
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
    if (goal === 'strength' && ex.mechanics === 'compound') score += 20;
    return score + Math.random() * 5; // Shuffle
}

/**
 * Konfiguruje objętość ćwiczenia zgodnie ze standardami NSCA
 * - Siła: 3-5 serii x 3-6 powt, dłuższe przerwy (3-5 min)
 * - Hipertrofia: 3-4 serii x 8-12 powt, średnie przerwy (60-90s)
 * - Wytrzymałość: 2-3 serii x 12-20 powt, krótkie przerwy (30-60s)
 */
function configureVolume(ex, level, goal, historyMap) {
    let sets = 3;
    let reps = "8-12";
    let rest = "60-90s";
    
    // Dopasuj objętość do poziomu i celu
    const isCompound = ex.mechanics === 'compound' || 
                       ['squat', 'hinge', 'push_h', 'push_v', 'pull_h', 'pull_v'].includes(ex.pattern);
    const isCore = ex.pattern === 'core';
    const isAccessory = ex.pattern === 'accessory' || ex.mechanics === 'isolation';
    
    // Konfiguracja wg poziomu
    if (level === 'beginner') {
        sets = isCompound ? 3 : 2;
        reps = isCore ? "15-20" : "10-12";
        rest = "90-120s";
    } else if (level === 'intermediate') {
        sets = isCompound ? 4 : 3;
        reps = isCompound ? "8-10" : "10-12";
        rest = "90s";
    } else { // advanced
        sets = isCompound ? 4 : 3;
        reps = isCompound ? "6-8" : "8-12";
        rest = "2-3min";
    }
    
    // Modyfikacja wg celu
    if (goal === 'strength') {
        if (isCompound) {
            sets = level === 'beginner' ? 4 : 5;
            reps = "3-5";
            rest = "3-5min";
        }
    } else if (goal === 'mass' || goal === 'hypertrophy') {
        sets = isCompound ? 4 : 3;
        reps = isCompound ? "8-10" : "10-12";
        rest = "60-90s";
    } else if (goal === 'endurance' || goal === 'tone') {
        sets = 3;
        reps = isCompound ? "12-15" : "15-20";
        rest = "30-60s";
    } else if (goal === 'fat_loss' || goal === 'recomposition') {
        sets = 3;
        reps = "10-12";
        rest = "45-60s";
    }
    
    // Core zawsze wyższe powtórzenia
    if (isCore) {
        reps = "15-20";
        sets = Math.min(sets, 3);
    }
    
    // Progresja ciężaru na podstawie historii
    let suggestedWeight = '';
    if (historyMap && historyMap[ex.code]) {
        const lastMax = parseFloat(historyMap[ex.code]);
        if (!isNaN(lastMax) && lastMax > 0) {
            const prog = lastMax * 1.025; // +2.5%
            suggestedWeight = (Math.round(prog * 2) / 2).toFixed(1);
        }
    }

    return {
        code: ex.code,
        name: ex.name || ex.name_en || ex.name_pl,
        name_en: ex.name_en,
        name_pl: ex.name_pl,
        sets,
        reps,
        rest,
        weight: suggestedWeight,
        pattern: ex.pattern,
        primary_muscle: ex.primary_muscle,
        description: ex.description || ex.instructions_en || ex.instructions_pl,
        instructions_en: ex.instructions_en,
        instructions_pl: ex.instructions_pl,
        video_url: ex.video_url
    };
}

function generateProgressionModel(level) {
    if (level === 'beginner') {
        return [
            { week: 1, note: "Tydzień 1: Naucz się techniki. Używaj lekkich ciężarów." },
            { week: 2, note: "Tydzień 2: Zwiększ ciężar o 2.5kg w głównych ćwiczeniach." },
            { week: 3, note: "Tydzień 3: Skup się na pełnym zakresie ruchu." },
            { week: 4, note: "Tydzień 4: Lżejszy tydzień - 75% normalnej objętości." }
        ];
    }
    return [
        { week: 1, note: "Tydzień 1: Adaptacja. RIR 3-4 (zostaw zapas)." },
        { week: 2, note: "Tydzień 2: Zwiększ ciężar o 2.5% lub +1 powtórzenie." },
        { week: 3, note: "Tydzień 3: Maksymalna intensywność (RIR 1-2)." },
        { week: 4, note: "Tydzień 4: Deload - 50% objętości, skup się na technice." }
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