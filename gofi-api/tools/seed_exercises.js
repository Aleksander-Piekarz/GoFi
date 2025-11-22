const fs = require('fs');
const path = require('path');
require('dotenv').config(); 


const { pool } = require('../lib/db'); 

(async () => {
  
  const poolPromise = pool.promise();
  let connection;

  try {
    
    connection = await poolPromise.getConnection();
    console.log("Pomyślnie połączono z bazą danych na potrzeby seedera.");
    connection.release();

    const exPath = path.join(__dirname, '..', 'data', 'exercises.json');
    const altPath = path.join(__dirname, '..', 'data', 'exercise_alternatives.json');
    const EX = JSON.parse(fs.readFileSync(exPath, 'utf8'));
    const ALT = fs.existsSync(altPath) ? JSON.parse(fs.readFileSync(altPath, 'utf8')) : [];

    console.log(`Seeding ${EX.length} exercises...`);
    for (const e of EX) {
      const equip = (e.equipment || []).join(',');
      const loc = (e.location || []).join(',');
      const secondary = (e.secondary_muscles || []).join(',');

      await poolPromise.query(
        `INSERT INTO exercises (code,name,primary_muscle,secondary_muscles,pattern,equipment,location,difficulty,unilateral,is_machine,minutes_est,notes,description,video_url)
         VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
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
           video_url=VALUES(video_url)`,
        [
          e.code, e.name, e.primary_muscle, secondary, e.pattern, equip, loc, 
          e.difficulty||2, !!e.unilateral, !!e.is_machine, e.minutes_est||6, 
          e.notes||null, e.description||null, e.video_url||null
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

    console.log('Seed done.');
  } catch (err) {
    
    console.error("BŁĄD PODCZAS SEEDOWANIA:", err.message);
    if (err.code) {
      console.error("Kod błędu:", err.code);
    }
  } finally {
    
    await pool.end();
    console.log("Pula połączeń zamknięta.");
  }
})();