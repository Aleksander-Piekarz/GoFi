const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config();

(async () => {
  const pool = await mysql.createPool({
    host: process.env.DB_HOST, user: process.env.DB_USER,
    password: process.env.DB_PASS, database: process.env.DB_NAME,
    waitForConnections: true, connectionLimit: 5
  });

  const exPath = path.join(__dirname, '..', 'data', 'exercises.json');
  const altPath = path.join(__dirname, '..', 'data', 'exercise_alternatives.json');
  const EX = JSON.parse(fs.readFileSync(exPath, 'utf8'));
  const ALT = fs.existsSync(altPath) ? JSON.parse(fs.readFileSync(altPath, 'utf8')) : [];

  console.log(`Seeding ${EX.length} exercises...`);
  for (const e of EX) {
    const equip = (e.equipment || []).join(',');
    const loc = (e.location || []).join(',');
    await pool.query(
      `INSERT INTO exercises (code,name,muscle_group,pattern,equipment,location,difficulty,unilateral,is_machine,minutes_est,notes)
       VALUES (?,?,?,?,?,?,?,?,?,?,?)
       ON DUPLICATE KEY UPDATE
         name=VALUES(name),
         muscle_group=VALUES(muscle_group),
         pattern=VALUES(pattern),
         equipment=VALUES(equipment),
         location=VALUES(location),
         difficulty=VALUES(difficulty),
         unilateral=VALUES(unilateral),
         is_machine=VALUES(is_machine),
         minutes_est=VALUES(minutes_est),
         notes=VALUES(notes)`,
      [e.code, e.name, e.muscle_group, e.pattern, equip, loc, e.difficulty||2, !!e.unilateral, !!e.is_machine, e.minutes_est||6, e.notes||null]
    );
  }

  console.log(`Seeding ${ALT.length} alternatives...`);
  for (const [base, alt] of ALT) {
    await pool.query(
      `INSERT IGNORE INTO exercise_alternatives (exercise_code, alt_code) VALUES (?,?)`,
      [base, alt]
    );
  }

  await pool.end();
  console.log('Seed done.');
})();
