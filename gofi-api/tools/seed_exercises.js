const fs = require('fs');
const path = require('path');
require('dotenv').config(); 

const { pool } = require('../lib/db'); 

// Pomocnicza funkcja do konwersji tablic na stringi CSV
const arrayToCsv = (val) => {
  if (!val) return '';
  if (Array.isArray(val)) return val.join(',');
  return String(val);
};

// Pomocnicza funkcja do mapowania trudności (słowa -> liczby)
const parseDifficulty = (val) => {
  if (typeof val === 'number') return val;
  if (!val) return 2; // Domyślnie średni
  
  const lower = String(val).toLowerCase();
  if (lower.includes('beginner') || lower.includes('easy')) return 1;
  if (lower.includes('intermediate') || lower.includes('medium')) return 2;
  if (lower.includes('advanced') || lower.includes('hard')) return 3;
  
  return 2; // Fallback
};

// Pomocnicza funkcja do wyciągania nazwy z obiektu wielojęzycznego
const getLocalizedName = (nameObj) => {
  if (typeof nameObj === 'string') return nameObj;
  if (nameObj && typeof nameObj === 'object') {
    return nameObj.en || nameObj.pl || '';
  }
  return '';
};

// Pomocnicza funkcja do konwersji obiektu/tablicy na JSON string
const toJsonString = (val) => {
  if (!val) return null;
  if (typeof val === 'string') return val;
  return JSON.stringify(val);
};

(async () => {
  const poolPromise = pool.promise();

  try {
    const connection = await poolPromise.getConnection();
    console.log("Pomyślnie połączono z bazą danych.");
    connection.release();

    // Najpierw sprawdź exercises_final.json, potem exercises.json
    const exFinalPath = path.join(__dirname, '..', 'data', 'exercises_final.json');
    const exPath = path.join(__dirname, '..', 'data', 'exercises.json');
    const altPath = path.join(__dirname, '..', 'data', 'exercise_alternatives.json');
    
    let exercisesFile = exFinalPath;
    if (!fs.existsSync(exFinalPath)) {
      if (!fs.existsSync(exPath)) {
        throw new Error("Brak pliku exercises_final.json ani exercises.json");
      }
      exercisesFile = exPath;
      console.log("Używam exercises.json (brak exercises_final.json)");
    } else {
      console.log("Używam exercises_final.json");
    }

    const EX = JSON.parse(fs.readFileSync(exercisesFile, 'utf8'));
    // Obsługa braku pliku z alternatywami (opcjonalny)
    const ALT = fs.existsSync(altPath) ? JSON.parse(fs.readFileSync(altPath, 'utf8')) : [];

    console.log(`Seeding ${EX.length} exercises...`);

    // Najpierw upewnij się, że tabela ma potrzebne kolumny
    // Dodajemy nowe kolumny jeśli nie istnieją (dla wielojęzycznych danych)
    try {
      await poolPromise.query(`
        ALTER TABLE exercises 
        ADD COLUMN IF NOT EXISTS name_en VARCHAR(255) DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS name_pl VARCHAR(255) DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS instructions_en TEXT DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS instructions_pl TEXT DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS common_mistakes_en TEXT DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS common_mistakes_pl TEXT DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS images TEXT DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS safety_data TEXT DEFAULT NULL
      `);
      console.log("Sprawdzono/dodano kolumny wielojęzyczne.");
    } catch (alterErr) {
      // Ignoruj błędy ALTER TABLE (np. jeśli kolumny już istnieją w starszym MySQL)
      console.log("Info: ALTER TABLE (kolumny mogą już istnieć):", alterErr.message);
    }
    
    let successCount = 0;
    let errorCount = 0;

    for (const e of EX) {
      try {
        // 1. Obsługa nazwy wielojęzycznej
        const nameEn = e.name?.en || (typeof e.name === 'string' ? e.name : '');
        const namePl = e.name?.pl || nameEn;
        const displayName = nameEn || namePl || e.code; // Fallback dla głównego name

        // 2. Konwersja pól tablicowych na stringi (CSV)
        const equip = typeof e.equipment === 'string' ? e.equipment : arrayToCsv(e.equipment);
        const loc = arrayToCsv(e.location);
        const secondary = arrayToCsv(e.secondary_muscles);
        
        // 3. Excluded injuries z safety lub bezpośrednio
        const injuries = e.safety?.excluded_injuries 
          ? arrayToCsv(e.safety.excluded_injuries) 
          : arrayToCsv(e.excluded_injuries);
        
        // 4. Konwersja trudności na liczbę (dla algorytmu)
        const diff = parseDifficulty(e.difficulty);

        // 5. Domyślne wartości
        const mechanics = e.mechanics || 'compound';
        const pattern = e.pattern || 'accessory';

        // 6. Instrukcje i błędy jako JSON
        const instructionsEn = toJsonString(e.instructions?.en);
        const instructionsPl = toJsonString(e.instructions?.pl);
        const mistakesEn = toJsonString(e.common_mistakes?.en);
        const mistakesPl = toJsonString(e.common_mistakes?.pl);
        
        // 7. Obrazy i dane bezpieczeństwa
        const images = toJsonString(e.images);
        const safetyData = toJsonString(e.safety);

        await poolPromise.query(
          `INSERT INTO exercises (
              code, name_en, name_pl, primary_muscle, secondary_muscles, pattern, 
              equipment, location, difficulty, unilateral, is_machine, 
              minutes_est, video_url, 
              mechanics,
              instructions_en, instructions_pl, common_mistakes_en, common_mistakes_pl,
              images, safety_data
           )
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
           ON DUPLICATE KEY UPDATE
              name_en=VALUES(name_en),
              name_pl=VALUES(name_pl),
              primary_muscle=VALUES(primary_muscle),
              secondary_muscles=VALUES(secondary_muscles),
              pattern=VALUES(pattern),
              equipment=VALUES(equipment),
              location=VALUES(location),
              difficulty=VALUES(difficulty),
              unilateral=VALUES(unilateral),
              is_machine=VALUES(is_machine),
              minutes_est=VALUES(minutes_est),
              video_url=VALUES(video_url),
              mechanics=VALUES(mechanics),
              instructions_en=VALUES(instructions_en),
              instructions_pl=VALUES(instructions_pl),
              common_mistakes_en=VALUES(common_mistakes_en),
              common_mistakes_pl=VALUES(common_mistakes_pl),
              images=VALUES(images),
              safety_data=VALUES(safety_data)`,
          [
            e.code, nameEn, namePl, e.primary_muscle, secondary, pattern, 
            equip, loc, diff, !!e.unilateral, !!e.is_machine, 
            e.minutes_est || 6, e.video_url || null,
            mechanics,
            instructionsEn, instructionsPl, mistakesEn, mistakesPl,
            images, safetyData
          ]
        );
        successCount++;
        
        // Wyświetl postęp co 100 ćwiczeń
        if (successCount % 100 === 0) {
          console.log(`  Przetworzono ${successCount} ćwiczeń...`);
        }
      } catch (exErr) {
        errorCount++;
        console.error(`  Błąd dla ćwiczenia "${e.code}":`, exErr.message);
      }
    }

    console.log(`✓ Zapisano ${successCount} ćwiczeń (${errorCount} błędów)`);

    // Seedowanie alternatyw
    if (ALT.length > 0) {
      console.log(`Seeding ${ALT.length} alternative groups...`);
      
      await poolPromise.query("DELETE FROM exercise_alternatives");
      
      let altCount = 0;
      for (const pairList of ALT) {
        for (const exerciseCode of pairList) {
          for (const altCode of pairList) {
            if (exerciseCode !== altCode) {
              await poolPromise.query(
                `INSERT IGNORE INTO exercise_alternatives (exercise_code, alt_code) VALUES (?,?)`,
                [exerciseCode, altCode]
              );
              altCount++;
            }
          }
        }
      }
      console.log(`✓ Zapisano ${altCount} powiązań alternatyw`);
    }

    // Generowanie alternatyw na podstawie wzorca i partii mięśniowej
    console.log("Generowanie automatycznych alternatyw...");
    
    const [exercises] = await poolPromise.query(
      `SELECT code, primary_muscle, pattern FROM exercises WHERE primary_muscle IS NOT NULL`
    );
    
    let autoAltCount = 0;
    const processed = new Set();
    
    for (const ex of exercises) {
      if (processed.has(ex.code)) continue;
      
      // Znajdź ćwiczenia z tym samym wzorcem i partią mięśniową
      const [similar] = await poolPromise.query(
        `SELECT code FROM exercises 
         WHERE primary_muscle = ? AND pattern = ? AND code != ?
         LIMIT 5`,
        [ex.primary_muscle, ex.pattern, ex.code]
      );
      
      for (const sim of similar) {
        await poolPromise.query(
          `INSERT IGNORE INTO exercise_alternatives (exercise_code, alt_code) VALUES (?,?)`,
          [ex.code, sim.code]
        );
        await poolPromise.query(
          `INSERT IGNORE INTO exercise_alternatives (exercise_code, alt_code) VALUES (?,?)`,
          [sim.code, ex.code]
        );
        autoAltCount++;
      }
      
      processed.add(ex.code);
    }
    
    console.log(`✓ Wygenerowano ${autoAltCount} automatycznych alternatyw`);

    console.log('\n========================================');
    console.log('Seed zakończony sukcesem!');
    console.log('========================================');
  } catch (err) {
    console.error("\nBŁĄD SEEDOWANIA:", err.message);
    if (err.sqlMessage) console.error("SQL Error:", err.sqlMessage);
  } finally {
    await pool.end();
  }
})();