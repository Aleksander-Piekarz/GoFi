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

(async () => {
  const poolPromise = pool.promise();

  try {
    const connection = await poolPromise.getConnection();
    console.log("Pomyślnie połączono z bazą danych.");
    connection.release();

    const exPath = path.join(__dirname, '..', 'data', 'exercises.json');
    const altPath = path.join(__dirname, '..', 'data', 'exercise_alternatives.json');
    
    if (!fs.existsSync(exPath)) throw new Error("Brak pliku exercises.json");

    const EX = JSON.parse(fs.readFileSync(exPath, 'utf8'));
    // Obsługa braku pliku z alternatywami (opcjonalny)
    const ALT = fs.existsSync(altPath) ? JSON.parse(fs.readFileSync(altPath, 'utf8')) : [];

    console.log(`Seeding ${EX.length} exercises...`);
    
    for (const e of EX) {
      // 1. Konwersja pól tablicowych na stringi (CSV)
      const equip = arrayToCsv(e.equipment);
      const loc = arrayToCsv(e.location);
      const secondary = arrayToCsv(e.secondary_muscles); // Zabezpieczenie przed brakiem pola
      const injuries = arrayToCsv(e.excluded_injuries);
      
      // 2. Konwersja trudności na liczbę (dla algorytmu)
      const diff = parseDifficulty(e.difficulty);

      // 3. Domyślne wartości
      const mechanics = e.mechanics || 'compound';
      const pattern = e.pattern || 'accessory'; // Zabezpieczenie przed pustym patternem

      await poolPromise.query(
        `INSERT INTO exercises (
            code, name, primary_muscle, secondary_muscles, pattern, 
            equipment, location, difficulty, unilateral, is_machine, 
            minutes_est, notes, description, video_url, 
            mechanics, excluded_injuries
         )
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
         ON DUPLICATE KEY UPDATE
            name=VALUES(name),
            primary_muscle=VALUES(primary_muscle),
            secondary_muscles=VALUES(secondary_muscles),
            pattern=VALUES(pattern),
            equipment=VALUES(equipment),
            location=VALUES(location),
            difficulty=VALUES(difficulty),
            unilateral=VALUES(unilateral),
            is_machine=VALUES(is_machine),
            minutes_est=VALUES(minutes_est),
            notes=VALUES(notes),
            description=VALUES(description),
            video_url=VALUES(video_url),
            mechanics=VALUES(mechanics),
            excluded_injuries=VALUES(excluded_injuries)`,
        [
          e.code, e.name, e.primary_muscle, secondary, pattern, 
          equip, loc, diff, !!e.unilateral, !!e.is_machine, 
          e.minutes_est||6, e.notes||null, e.description||null, e.video_url||null,
          mechanics, injuries 
        ]
      );
    }

    console.log(`Seeding ${ALT.length} alternative groups...`);
    
    await poolPromise.query("DELETE FROM exercise_alternatives");
    
    for (const pairList of ALT) {
      for (const exerciseCode of pairList) {
        for (const altCode of pairList) {
          if (exerciseCode !== altCode) {
            await poolPromise.query(
              `INSERT IGNORE INTO exercise_alternatives (exercise_code, alt_code) VALUES (?,?)`,
              [exerciseCode, altCode]
            );
          }
        }
      }
    }

    console.log('Seed zakończony sukcesem.');
  } catch (err) {
    console.error("BŁĄD SEEDOWANIA:", err.message);
    // Logowanie szczegółów błędu bazy danych, jeśli dostępne
    if (err.sqlMessage) console.error("SQL Error:", err.sqlMessage);
  } finally {
    await pool.end();
  }
})();