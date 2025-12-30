const { pool } = require("../lib/db");

exports.getAlternatives = async (req, res) => {
  const { code } = req.params;
  
  if (!code) {
    return res.status(400).json({ error: "Brak kodu ćwiczenia" });
  }

  try {
    const poolPromise = pool.promise();
    
    // 1. Znajdź kody alternatyw
    const [altRows] = await poolPromise.query(
      "SELECT alt_code FROM exercise_alternatives WHERE exercise_code = ?",
      [code]
    );

    if (altRows.length === 0) {
      return res.json([]);
    }

    const altCodes = altRows.map(row => row.alt_code);

    // 2. Pobierz pełne dane tych ćwiczeń
    // Używamy IN (?) i przekazujemy tablicę kodów
    const [exercises] = await poolPromise.query(
      `SELECT code, name, equipment, primary_muscle, video_url, description 
       FROM exercises 
       WHERE code IN (?)`,
      [altCodes]
    );

    // Parsowanie equipment (z CSV na tablicę) dla frontend'u
    const parsedExercises = exercises.map(ex => ({
      ...ex,
      equipment: ex.equipment ? ex.equipment.split(',') : []
    }));

    res.json(parsedExercises);

  } catch (error) {
    console.error("Błąd pobierania alternatyw:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
};