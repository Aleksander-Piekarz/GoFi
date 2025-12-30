const { pool } = require("../lib/db");
const algorithm = require("../lib/algorithm"); // Importujemy nasz nowy moduł

// Helper do pobrania wszystkich ćwiczeń (potrzebne dla algorytmu)
async function getAllExercises(poolPromise) {
    const sql = `
      SELECT 
        code, name, primary_muscle, secondary_muscles, pattern, 
        equipment, location, difficulty, unilateral, is_machine, 
        minutes_est, description, video_url,
        mechanics, excluded_injuries
      FROM exercises
    `;
    const [rows] = await poolPromise.query(sql);
    
    // Parsowanie danych z bazy (stringi 'a,b,c' na tablice ['a','b','c'])
    return rows.map(ex => ({
        ...ex,
        equipment: ex.equipment ? ex.equipment.split(',') : [],
        location: ex.location ? ex.location.split(',') : [],
        excluded_injuries: ex.excluded_injuries ? ex.excluded_injuries.split(',') : [],
        difficulty: parseInt(ex.difficulty) || 2
    }));
}

// Helper do historii ciężarów
async function getUserMaxWeights(poolPromise, userId) {
    try {
        const [rows] = await poolPromise.query(`
            SELECT exercise_code, MAX(weight) as max_weight
            FROM workout_log_sets WHERE user_id = ? GROUP BY exercise_code
        `, [userId]);
        const map = {};
        rows.forEach(r => map[r.exercise_code] = r.max_weight);
        return map;
    } catch (e) {
        console.error("History fetch error:", e);
        return {};
    }
}

// --- HANDLERY ---

exports.getQuestions = async (req, res) => {
    res.json(algorithm.QUESTIONS);
};

exports.submitAnswers = async (req, res) => {
    try {
        const answers = req.body || {};
        const userId = req.user?.id;
        if (!userId) return res.status(401).json({ error: "Unauthorized" });

        // Walidacja
        const errors = algorithm.validateAnswers(answers);
        if (errors.length) return res.status(400).json({ error: "Validation failed", details: errors });

        const poolPromise = pool.promise();

        // 1. Zapis Ankiety
        const [qResult] = await poolPromise.query(
            "INSERT INTO questionnaires (user_id, answers_json, created_at) VALUES (?, ?, NOW())",
            [userId, JSON.stringify(answers)]
        );

        // 2. Przygotowanie danych dla algorytmu
        const allExercises = await getAllExercises(poolPromise);
        const historyMap = await getUserMaxWeights(poolPromise, userId);
        
        // Normalizacja sprzętu (dodajemy bodyweight/none zawsze)
        let userEquipment = answers.equipment || [];
        if (!userEquipment.includes('bodyweight')) userEquipment.push('bodyweight');
        if (!userEquipment.includes('none')) userEquipment.push('none');

        const userProfile = {
            experience: answers.experience || 'beginner',
            daysPerWeek: answers.days_per_week || 3,
            injuries: answers.injuries || [],
            equipment: userEquipment,
            goal: answers.goal || 'recomposition',
            location: answers.location || 'gym'
        };

        // 3. Generowanie Planu (Logika CSCS)
        const plan = algorithm.generateAdvancedPlan(userProfile, allExercises, historyMap);
        
        if (!plan) {
            return res.status(500).json({ error: "Nie udało się wygenerować planu. Sprawdź kryteria." });
        }

        // 4. Zapis Planu
        const [pResult] = await poolPromise.query(
            "INSERT INTO plans (user_id, source_questionnaire_id, plan_json, created_at) VALUES (?, ?, ?, NOW())",
            [userId, qResult.insertId, JSON.stringify(plan)]
        );

        res.json({
            ok: true,
            planId: pResult.insertId,
            plan: plan
        });

    } catch (error) {
        console.error("Błąd w submitAnswers:", error);
        res.status(500).json({ error: "Błąd serwera." });
    }
};

exports.getLatestPlan = async (req, res) => {
    try {
        const userId = req.user?.id;
        const [rows] = await pool.promise().query(
            "SELECT plan_json FROM plans WHERE user_id=? ORDER BY id DESC LIMIT 1", [userId]
        );
        if (!rows.length) return res.json({});
        const plan = typeof rows[0].plan_json === 'string' ? JSON.parse(rows[0].plan_json) : rows[0].plan_json;
        res.json(plan);
    } catch (e) {
        console.error(e);
        res.status(500).json({ error: "Błąd pobierania planu" });
    }
};

exports.saveAnswers = async (req, res) => {
    // Prosty zapis bez generowania (np. draft)
    try {
        const userId = req.user?.id;
        await pool.promise().query(
            "INSERT INTO questionnaires (user_id, answers_json, created_at) VALUES (?, ?, NOW())",
            [userId, JSON.stringify(req.body)]
        );
        res.json({ ok: true });
    } catch (e) {
        res.status(500).json({ error: "Błąd zapisu" });
    }
};

exports.getLatestAnswers = async (req, res) => {
    try {
        const userId = req.user?.id;
        const [rows] = await pool.promise().query(
            "SELECT answers_json FROM questionnaires WHERE user_id=? ORDER BY id DESC LIMIT 1", [userId]
        );
        if (!rows.length) return res.json({});
        res.json(typeof rows[0].answers_json === 'string' ? JSON.parse(rows[0].answers_json) : rows[0].answers_json);
    } catch (e) {
        res.status(500).json({ error: "Błąd pobierania odpowiedzi" });
    }
};