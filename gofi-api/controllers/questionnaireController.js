const { pool } = require("../lib/db");
const algorithm = require("../lib/algorithm"); // Importujemy nasz nowy moduł
const fs = require('fs');
const path = require('path');

// Ścieżki do plików JSON z ćwiczeniami (fallback gdy baza niedostępna)
const EXERCISES_JSON_PATHS = [
    path.join(__dirname, '../data/exercises_final.json'),
    path.join(__dirname, '../data/exercises.json')
];

// Helper do pobrania wszystkich ćwiczeń (potrzebne dla algorytmu)
async function getAllExercises(poolPromise) {
    // Próbuj najpierw z bazy danych
    try {
        const sql = `
          SELECT 
            code, name_en, name_pl, primary_muscle, secondary_muscles, pattern, 
            equipment, location, difficulty, unilateral, is_machine, 
            minutes_est, instructions_en, instructions_pl, video_url,
            mechanics, safety_data
          FROM exercises
        `;
        const [rows] = await poolPromise.query(sql);
        
        if (rows.length > 0) {
            console.log(`Załadowano ${rows.length} ćwiczeń z bazy danych`);
            // Parsowanie danych z bazy (stringi 'a,b,c' na tablice ['a','b','c'])
            return rows.map(ex => {
                // Parsuj safety_data JSON aby wyciągnąć excluded_injuries
                let excludedInjuries = [];
                if (ex.safety_data) {
                    try {
                        const safety = JSON.parse(ex.safety_data);
                        excludedInjuries = safety.excluded_injuries || [];
                    } catch (e) { /* ignore parse errors */ }
                }
                return {
                    ...ex,
                    name: ex.name_en || ex.name_pl, // Kompatybilność wsteczna
                    description: ex.instructions_en || ex.instructions_pl,
                    equipment: ex.equipment ? ex.equipment.split(',') : [],
                    location: ex.location ? ex.location.split(',') : [],
                    excluded_injuries: excludedInjuries,
                    difficulty: parseInt(ex.difficulty) || 2
                };
            });
        }
    } catch (dbError) {
        console.warn('Baza danych niedostępna, próbuję załadować z JSON:', dbError.code);
    }
    
    // Fallback: ładuj z pliku JSON
    return loadExercisesFromJson();
}

// Ładuje ćwiczenia z pliku JSON
function loadExercisesFromJson() {
    for (const jsonPath of EXERCISES_JSON_PATHS) {
        try {
            if (fs.existsSync(jsonPath)) {
                const data = fs.readFileSync(jsonPath, 'utf8');
                const exercises = JSON.parse(data);
                console.log(`Załadowano ${exercises.length} ćwiczeń z JSON: ${path.basename(jsonPath)}`);
                
                // Normalizuj dane z JSON do formatu oczekiwanego przez algorytm
                return exercises.map(ex => ({
                    ...ex,
                    name: ex.name || ex.name_en || ex.name_pl,
                    name_en: ex.name_en || ex.name,
                    name_pl: ex.name_pl || ex.name,
                    description: ex.description || ex.instructions_en || ex.instructions_pl,
                    // Normalizacja equipment - może być string lub tablica
                    equipment: normalizeToArray(ex.equipment),
                    // Normalizacja location - może być string, tablica lub undefined
                    location: normalizeToArray(ex.location, ['gym', 'home']), // domyślnie wszędzie
                    excluded_injuries: ex.excluded_injuries || ex.safety?.excluded_injuries || [],
                    difficulty: parseInt(ex.difficulty) || 2,
                    pattern: ex.pattern || 'accessory'
                }));
            }
        } catch (err) {
            console.warn(`Nie udało się załadować ${jsonPath}:`, err.message);
        }
    }
    console.error('Nie znaleziono żadnego pliku z ćwiczeniami!');
    return [];
}

// Normalizuje wartość do tablicy
function normalizeToArray(value, defaultValue = []) {
    if (!value) return defaultValue;
    if (Array.isArray(value)) return value;
    if (typeof value === 'string') {
        // Obsłuż różne formaty: "gym,home" lub "body weight" itp.
        return value.split(',').map(s => s.trim().toLowerCase());
    }
    return defaultValue;
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
            daysPerWeek: parseInt(answers.days_per_week) || 3,
            injuries: answers.injuries || [],
            equipment: userEquipment,
            goal: answers.goal || 'recomposition',
            location: answers.location || 'gym',
            preferredDays: answers.preferred_days || [], // Preferowane dni treningowe
            sessionTime: parseInt(answers.session_time) || 60 // Czas sesji w minutach
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

// --- WŁASNY PLAN ---
exports.saveCustomPlan = async (req, res) => {
    try {
        const userId = req.user?.id;
        if (!userId) return res.status(401).json({ error: "Unauthorized" });
        
        const plan = req.body;
        if (!plan || !plan.week || !Array.isArray(plan.week)) {
            return res.status(400).json({ error: "Nieprawidłowy format planu" });
        }

        const poolPromise = pool.promise();

        // Zapisz plan z flagą custom=true
        const [pResult] = await poolPromise.query(
            "INSERT INTO plans (user_id, source_questionnaire_id, plan_json, created_at) VALUES (?, NULL, ?, NOW())",
            [userId, JSON.stringify({ ...plan, custom: true })]
        );

        res.json({
            ok: true,
            planId: pResult.insertId,
            plan: plan
        });

    } catch (error) {
        console.error("Błąd w saveCustomPlan:", error);
        res.status(500).json({ error: "Błąd serwera." });
    }
};
