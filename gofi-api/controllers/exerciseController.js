const { pool } = require("../lib/db");
const fs = require('fs');
const path = require('path');

// Ścieżki do plików JSON z ćwiczeniami (w kolejności preferencji)
const EXERCISES_JSON_PATHS = [
  path.join(__dirname, '../data/exercises_final.json'),
  path.join(__dirname, '../data/exercises.json')
];

// Cache dla ćwiczeń z JSON (ładowane raz)
let exercisesCache = null;

/**
 * Ładuje ćwiczenia z pliku JSON do pamięci cache
 */
function loadExercisesFromJson() {
  if (exercisesCache === null) {
    for (const jsonPath of EXERCISES_JSON_PATHS) {
      try {
        if (fs.existsSync(jsonPath)) {
          const data = fs.readFileSync(jsonPath, 'utf8');
          exercisesCache = JSON.parse(data);
          console.log(`Załadowano ${exercisesCache.length} ćwiczeń z ${path.basename(jsonPath)}`);
          break;
        }
      } catch (error) {
        console.error(`Błąd ładowania ${path.basename(jsonPath)}:`, error.message);
      }
    }
    if (exercisesCache === null) {
      console.error('Nie znaleziono żadnego pliku z ćwiczeniami!');
      exercisesCache = [];
    }
  }
  return exercisesCache;
}

/**
 * Pobiera pełne dane ćwiczenia po kodzie
 */
exports.getExerciseByCode = async (req, res) => {
  const { code } = req.params;
  
  if (!code) {
    return res.status(400).json({ error: "Brak kodu ćwiczenia" });
  }

  try {
    const exercises = loadExercisesFromJson();
    const exercise = exercises.find(ex => ex.code === code);
    
    if (!exercise) {
      return res.status(404).json({ error: "Nie znaleziono ćwiczenia" });
    }

    res.json(exercise);
  } catch (error) {
    console.error("Błąd pobierania ćwiczenia:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
};

/**
 * Pobiera listę wszystkich ćwiczeń z filtrowaniem
 */
exports.getAllExercises = async (req, res) => {
  const { 
    page = 1, 
    limit = 50, 
    muscle, 
    equipment, 
    difficulty, 
    search,
    pattern 
  } = req.query;

  try {
    let exercises = loadExercisesFromJson();

    // Filtrowanie
    if (muscle) {
      exercises = exercises.filter(ex => 
        ex.primary_muscle?.toLowerCase() === muscle.toLowerCase() ||
        ex.secondary_muscles?.some(m => m.toLowerCase() === muscle.toLowerCase())
      );
    }

    if (equipment) {
      exercises = exercises.filter(ex => 
        ex.equipment?.toLowerCase().includes(equipment.toLowerCase())
      );
    }

    if (difficulty) {
      exercises = exercises.filter(ex => 
        ex.difficulty?.toLowerCase() === difficulty.toLowerCase()
      );
    }

    if (pattern) {
      exercises = exercises.filter(ex => 
        ex.pattern?.toLowerCase() === pattern.toLowerCase()
      );
    }

    if (search) {
      const searchLower = search.toLowerCase();
      exercises = exercises.filter(ex => 
        ex.code?.toLowerCase().includes(searchLower) ||
        ex.name?.en?.toLowerCase().includes(searchLower) ||
        ex.name?.pl?.toLowerCase().includes(searchLower) ||
        ex.primary_muscle?.toLowerCase().includes(searchLower)
      );
    }

    // Paginacja
    const startIndex = (parseInt(page) - 1) * parseInt(limit);
    const endIndex = startIndex + parseInt(limit);
    const paginatedExercises = exercises.slice(startIndex, endIndex);

    res.json({
      data: paginatedExercises,
      total: exercises.length,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(exercises.length / parseInt(limit))
    });
  } catch (error) {
    console.error("Błąd pobierania listy ćwiczeń:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
};

/**
 * Pobiera unikalne partie mięśniowe
 */
exports.getMuscleGroups = async (req, res) => {
  try {
    const exercises = loadExercisesFromJson();
    const muscles = new Set();
    
    exercises.forEach(ex => {
      if (ex.primary_muscle) {
        muscles.add(ex.primary_muscle.toLowerCase());
      }
    });

    res.json({ data: Array.from(muscles).sort() });
  } catch (error) {
    console.error("Błąd pobierania partii mięśniowych:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
};

/**
 * Pobiera unikalne typy sprzętu
 */
exports.getEquipmentTypes = async (req, res) => {
  try {
    const exercises = loadExercisesFromJson();
    const equipment = new Set();
    
    exercises.forEach(ex => {
      if (ex.equipment) {
        equipment.add(ex.equipment.toLowerCase());
      }
    });

    res.json({ data: Array.from(equipment).sort() });
  } catch (error) {
    console.error("Błąd pobierania typów sprzętu:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
};

exports.getAlternatives = async (req, res) => {
  const { code } = req.params;
  
  if (!code) {
    return res.status(400).json({ error: "Brak kodu ćwiczenia" });
  }

  try {
    // Najpierw spróbuj z bazy danych
    const poolPromise = pool.promise();
    
    const [altRows] = await poolPromise.query(
      "SELECT alt_code FROM exercise_alternatives WHERE exercise_code = ?",
      [code]
    );

    if (altRows.length > 0) {
      const altCodes = altRows.map(row => row.alt_code);
      
      // Pobierz pełne dane z JSON
      const exercises = loadExercisesFromJson();
      const alternatives = exercises.filter(ex => altCodes.includes(ex.code));
      
      return res.json(alternatives);
    }

    // Jeśli nie ma w bazie, znajdź podobne ćwiczenia z JSON
    const exercises = loadExercisesFromJson();
    const currentExercise = exercises.find(ex => ex.code === code);
    
    if (!currentExercise) {
      return res.json([]);
    }

    // Znajdź alternatywy na podstawie tej samej partii mięśniowej i wzorca
    const alternatives = exercises.filter(ex => 
      ex.code !== code &&
      ex.primary_muscle === currentExercise.primary_muscle &&
      ex.pattern === currentExercise.pattern
    ).slice(0, 5); // Ogranicz do 5 alternatyw

    res.json(alternatives);

  } catch (error) {
    console.error("Błąd pobierania alternatyw:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
};