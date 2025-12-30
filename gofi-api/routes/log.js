const express = require("express");
const router = express.Router();
const { auth } = require("../middleware/auth");
const { pool } = require("../lib/db"); // ⭐️ Używa globalnej puli

// ---
// 1. ZAPISYWANIE TRENINGU
// ---
router.post("/workout", auth(true), async (req, res) => {
  const userId = req.user?.id;
  // --- ZMIANA: Pobieramy też date_completed oraz name (dla kompatybilności) ---
  const { planName, name, exercises, date_completed } = req.body; 

  if (!exercises || !Array.isArray(exercises) || exercises.length === 0) {
    return res.status(400).json({ error: "Brak ćwiczeń do zapisania." });
  }

  let connection;
  try {
    // ⭐️ Używa pool.promise()
    connection = await pool.promise().getConnection();
    await connection.beginTransaction();

    // --- ZMIANA: Logika ustalania daty i nazwy ---
    // Jeśli data została przesłana (np. z generatora), użyj jej. W przeciwnym razie data dzisiejsza.
    const dateToSave = date_completed ? new Date(date_completed) : new Date();
    
    // Jeśli planName jest puste, spróbuj użyć 'name', a ostatecznie "Trening"
    const nameToSave = planName || name || "Trening";

    const [logResult] = await connection.query(
      "INSERT INTO workout_logs (user_id, plan_name, date_completed) VALUES (?, ?, ?)",
      [userId, nameToSave, dateToSave]
    );
    const newLogId = logResult.insertId;

    const setsToInsert = [];
    for (const ex of exercises) {
      if (!ex.sets || !Array.isArray(ex.sets)) continue;

      ex.sets.forEach((set, index) => {
        setsToInsert.push([
          newLogId,
          userId,
          ex.code || "UNKNOWN",
          index + 1, 
          parseInt(set.reps) || 0,
          parseFloat(set.weight) || 0,
        ]);
      });
    }

    if (setsToInsert.length === 0) {
      await connection.rollback();
      return res.status(400).json({ error: "Brak serii do zapisania." });
    }

    const sql = "INSERT INTO workout_log_sets (workout_log_id, user_id, exercise_code, set_number, reps, weight) VALUES ?";
    await connection.query(sql, [setsToInsert]);

    await connection.commit();
    res.json({ ok: true, logId: newLogId, setsSaved: setsToInsert.length });

  } catch (error) {
    console.error("Błąd podczas zapisywania logu treningu:", error);
    if (connection) await connection.rollback();
    res.status(500).json({ error: "Błąd serwera podczas zapisu treningu." });
  } finally {
    if (connection) connection.release();
  }
});

// ---
// 2. ENDPOINT: Lista zalogowanych ćwiczeń
// ---
router.get("/logged-exercises", auth(true), async (req, res) => {
  const userId = req.user.id;
  try {
    const sql = `
      SELECT 
        T1.exercise_code AS code,
        MAX(E.name) AS name, 
        MAX(T2.date_completed) AS last_logged
      FROM workout_log_sets AS T1
      JOIN workout_logs AS T2 ON T1.workout_log_id = T2.id
      LEFT JOIN exercises AS E ON T1.exercise_code = E.code
      WHERE T1.user_id = ?
      GROUP BY T1.exercise_code
      ORDER BY last_logged DESC
    `;
    
    // ⭐️ Używa pool.promise()
    const [rows] = await pool.promise().query(sql, [userId]);
    res.json(rows);

  } catch (error) {
    console.error("Błąd pobierania listy zalogowanych ćwiczeń:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
});

// ---
// 3. ENDPOINT: Historia dla pojedynczego ćwiczenia
// ---
router.get("/exercise/:code", auth(true), async (req, res) => {
  const userId = req.user.id;
  const exerciseCode = req.params.code;

  if (!exerciseCode) {
    return res.status(400).json({ error: "Brak kodu ćwiczenia" });
  }

  try {
    const sql = `
      SELECT 
        MAX(T1.weight) AS max_weight,
        DATE(T2.date_completed) AS date
      FROM workout_log_sets AS T1
      JOIN workout_logs AS T2 ON T1.workout_log_id = T2.id
      WHERE T1.user_id = ? AND T1.exercise_code = ? AND T1.weight > 0
      GROUP BY DATE(T2.date_completed)
      ORDER BY date ASC
    `;

    // ⭐️ Używa pool.promise()
    const [rows] = await pool.promise().query(sql, [userId, exerciseCode]);
    res.json(rows);

  } catch (error) {
    console.error("Błąd pobierania historii ćwiczenia:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
});

// ---
// 4. ENDPOINT: Lista wszystkich sesji treningowych
// ---
router.get("/workouts", auth(true), async (req, res) => {
  const userId = req.user.id;
  try {
    const sql = `
      SELECT id, plan_name, date_completed
      FROM workout_logs
      WHERE user_id = ?
      ORDER BY date_completed DESC
      LIMIT 50
    `;
    // ⭐️ Używa pool.promise()
    const [rows] = await pool.promise().query(sql, [userId]);
    res.json(rows);
  } catch (error) {
    console.error("Błąd pobierania listy logów treningowych:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
});

// ---
// 5. ENDPOINT: Szczegóły jednej sesji treningowej
// ---
router.get("/workout/:logId", auth(true), async (req, res) => {
  const userId = req.user.id;
  const logId = req.params.logId;
  try {
    const sql = `
      SELECT 
        S.exercise_code,
        E.name AS exercise_name,
        S.set_number,
        S.reps,
        S.weight
      FROM workout_log_sets AS S
      LEFT JOIN exercises AS E ON S.exercise_code = E.code
      WHERE S.workout_log_id = ? AND S.user_id = ?
      ORDER BY S.id ASC
    `;
    // ⭐️ Używa pool.promise()
    const [rows] = await pool.promise().query(sql, [logId, userId]);
    
    const exercisesMap = new Map();
    for (const row of rows) {
      if (!exercisesMap.has(row.exercise_code)) {
        exercisesMap.set(row.exercise_code, {
          code: row.exercise_code,
          name: row.exercise_name || row.exercise_code,
          sets: [],
        });
      }
      exercisesMap.get(row.exercise_code).sets.push({
        set: row.set_number,
        reps: row.reps,
        weight: row.weight,
      });
    }
    
    res.json(Array.from(exercisesMap.values()));
  } catch (error) {
    console.error("Błąd pobierania szczegółów logu treningu:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
});

// ---
// 6. ENDPOINT: Zapisywanie pomiaru wagi
// ---
router.post("/weight", auth(true), async (req, res) => {
  const userId = req.user?.id;
  const { weight } = req.body;

  const weightValue = parseFloat(weight);
  if (!weightValue || weightValue <= 0) {
    return res.status(400).json({ error: "Nieprawidłowa wartość wagi." });
  }

  try {
    const poolPromise = pool.promise();

    // 1. Sprawdź, czy istnieje już wpis z dzisiejszą datą
    const checkSql = `
      SELECT id FROM weight_logs 
      WHERE user_id = ? AND CAST(date_logged AS DATE) = CAST(NOW() AS DATE)
      LIMIT 1
    `;
    const [existing] = await poolPromise.query(checkSql, [userId]);

    if (existing.length > 0) {
      // UPDATE: Jeśli wpis istnieje, aktualizujemy go (nadpisujemy wagę)
      const updateSql = `
        UPDATE weight_logs 
        SET weight = ?, date_logged = NOW() 
        WHERE id = ?
      `;
      await poolPromise.query(updateSql, [weightValue, existing[0].id]);
      console.log(`Zaktualizowano wagę dla user ${userId} (ID logu: ${existing[0].id})`);
    } else {
      const insertSql = "INSERT INTO weight_logs (user_id, weight, date_logged) VALUES (?, ?, NOW())";
      await poolPromise.query(insertSql, [userId, weightValue]);
      console.log(`Dodano nową wagę dla user ${userId}`);
    }
    
    res.json({ ok: true, newWeight: weightValue });

  } catch (error) {
    console.error("Błąd podczas zapisywania wagi:", error);
    res.status(500).json({ error: "Błąd serwera podczas zapisu wagi." });
  }
});

// ---
// 7. ENDPOINT: Pobiera ostatnio logowane dane
// ---
router.post("/latest-for-exercises", auth(true), async (req, res) => {
  const userId = req.user.id;
  const { exerciseCodes } = req.body;

  if (!exerciseCodes || !Array.isArray(exerciseCodes) || exerciseCodes.length === 0) {
    return res.json({});
  }

  try {
    const sql = `
      WITH RankedSets AS (
        SELECT
          s.exercise_code,
          s.weight,
          s.reps,
          w.date_completed,
          ROW_NUMBER() OVER(
            PARTITION BY s.exercise_code 
            ORDER BY w.date_completed DESC, s.set_number ASC
          ) as rn
        FROM workout_log_sets s
        JOIN workout_logs w ON s.workout_log_id = w.id
        WHERE s.user_id = ? AND s.exercise_code IN (?)
      )
      SELECT exercise_code, weight, reps
      FROM RankedSets
      WHERE rn = 1;
    `;

    // ⭐️ Używa pool.promise()
    const [rows] = await pool.promise().query(sql, [userId, exerciseCodes]);

    const resultMap = rows.reduce((acc, row) => {
      acc[row.exercise_code] = {
        weight: row.weight.toString(),
        reps: row.reps,
      };
      return acc;
    }, {});

    res.json(resultMap);

  } catch (error){
    console.error("Błąd pobierania ostatnich logów dla ćwiczeń:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
});

router.get("/weight-history", auth(true), async (req, res) => {
  const userId = req.user.id;
  try {
    const sql = `
      SELECT weight, date_logged
      FROM weight_logs
      WHERE user_id = ?
      ORDER BY date_logged ASC
    `;
    const [rows] = await pool.promise().query(sql, [userId]);
    res.json(rows);
  } catch (error) {
    console.error("Błąd pobierania historii wagi:", error);
    res.status(500).json({ error: "Błąd serwera" });
  }
});

module.exports = router;