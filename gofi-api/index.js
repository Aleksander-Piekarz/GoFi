const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");
require("dotenv").config();

const app = express();
const port = 3000;

app.use(cors());
app.use(express.json());

// LOG każdą prośbę – zobaczysz w konsoli, czy dochodzi POST /login
app.use((req, _res, next) => { console.log(`${req.method} ${req.url}`); next(); });

// Healthcheck do szybkiego sprawdzenia
app.get("/health", (_req, res) => res.send("ok"));

// --- DB (jak masz .env; w razie czego to może być mock) ---
const db = mysql.createConnection({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  port: 3306,
});
db.connect(err => {
  if (err) console.log("Błąd połączenia z bazą:", err);
  else console.log("Połączono z bazą MySQL!");
});

// --- Rejestracja ---
app.post("/register", (req, res) => {
  const { email, username, password } = req.body ?? {};
  const q = "INSERT INTO users (username,email,password) VALUES (?,?,?)";
  db.query(q, [username, email, password], (err) => {
    if (err) return res.status(500).json({ error: "Błąd serwera" });
    res.json({ message: "Użytkownik zarejestrowany!" });
  });
});

// --- Logowanie (exactly /login) ---
app.post("/login", (req, res) => {
  const { email, password } = req.body ?? {};
  const q = "SELECT * FROM users WHERE email = ? AND password = ? LIMIT 1";
  db.query(q, [email, password], (err, rows) => {
    if (err) return res.status(500).json({ error: "Błąd serwera" });
    if (rows.length === 0) return res.status(401).json({ error: "Nieprawidłowy login lub hasło" });
    res.json({ message: "Zalogowano pomyślnie", user: rows[0] });
  });
});


// Kwestionariusz

const REQUIRED = [
  'age','weight','height','gender','goal','motivation','experience',
  'activityLevel','sleepHours','workType','availableDays','sessionLength'
];

const isMissing = (v) =>
  v === null || v === undefined || (typeof v === 'string' && v.trim() === '');


const norm = (v) =>
  (v === undefined || v === null || (typeof v === 'string' && v.trim() === ''))
    ? null
    : v;

// ---- SUBMIT (oznacz jako wysłane) ----
app.post('/users/:id/questionnaire/submit', (req, res) => {
  const userId = req.params.id;

  // 1) pobierz ankietę
  db.query('SELECT * FROM questionnaire WHERE user_id=? LIMIT 1', [userId], (err, rows) => {
    if (err) return res.status(500).json({ error: 'Błąd serwera' });
    if (rows.length === 0) return res.status(404).json({ error: 'Brak ankiety' });

    const q = rows[0];
    const missing = REQUIRED.filter(k => isMissing(q[k]));

    // (opcjonalnie) twardy wymóg kompletności przy submit
    if (missing.length > 0) {
      return res.status(400).json({
        error: 'Ankieta niekompletna',
        missing
      });
    }

    // 2) oznacz jako SUBMITTED
    db.query(
      'UPDATE questionnaire SET status="SUBMITTED", submitted_at=NOW() WHERE user_id=?',
      [userId],
      (err2, r) => {
        if (err2) return res.status(500).json({ error: 'Błąd serwera' });
        res.json({ message: 'Wysłano ankietę' });
      }
    );
  });
});

// ---- STATUS / PODGLĄD ----
app.get('/users/:id/questionnaire', (req, res) => {
  db.query('SELECT * FROM questionnaire WHERE user_id = ? LIMIT 1',
    [req.params.id],
    (err, rows) => {
      if (err) return res.status(500).json({ error: 'Błąd serwera' });
      if (rows.length === 0) return res.status(404).json({ exists: false });

      const q = rows[0];
      const missing = REQUIRED.filter(k => isMissing(q[k]));
      const complete = missing.length === 0;
      const progress = (REQUIRED.length - missing.length) / REQUIRED.length;

      return res.json({
        exists: true,
        status: complete ? 'SUBMITTED' : 'DRAFT',
        progress,                 // np. 0.85
        missing,                  // np. ["weight","height"]
        questionnaire: q
      });
    }
  );
});
// PUT /users/:id/questionnaire  — tworzy albo aktualizuje (UPSERT)
app.put('/users/:id/questionnaire', (req, res) => {
  const userId = req.params.id;
  const p = req.body || {};

  const sql = `
    INSERT INTO questionnaire
      (user_id, age, weight, height, gender, goal, motivation, experience,
       activityLevel, sleepHours, workType, availableDays, sessionLength,
       equipment, preferredExercises, injuries, illnesses)
    VALUES
      (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
      age=VALUES(age), weight=VALUES(weight), height=VALUES(height), gender=VALUES(gender),
      goal=VALUES(goal), motivation=VALUES(motivation), experience=VALUES(experience),
      activityLevel=VALUES(activityLevel), sleepHours=VALUES(sleepHours),
      workType=VALUES(workType), availableDays=VALUES(availableDays),
      sessionLength=VALUES(sessionLength), equipment=VALUES(equipment),
      preferredExercises=VALUES(preferredExercises), injuries=VALUES(injuries),
      illnesses=VALUES(illnesses), updated_at=CURRENT_TIMESTAMP
  `;

  const vals = [
    userId,
    norm(p.age), norm(p.weight), norm(p.height), norm(p.gender),
    norm(p.goal), norm(p.motivation), norm(p.experience),
    norm(p.activityLevel), norm(p.sleepHours), norm(p.workType),
    norm(p.availableDays), norm(p.sessionLength),
    norm(p.equipment), norm(p.preferredExercises),
    norm(p.injuries), norm(p.illnesses)
  ];

  db.query(sql, vals, (err) => {
    if (err) return res.status(500).json({ error: 'Błąd serwera', details: err.code });

    // po zapisie: pobierz rekord i policz kompletność
    db.query('SELECT * FROM questionnaire WHERE user_id=? LIMIT 1', [userId], (err2, rows) => {
      if (err2) return res.status(500).json({ error: 'Błąd serwera' });
      const q = rows[0];

      const missing = REQUIRED.filter(k => isMissing(q[k]));
      const complete = missing.length === 0;
      const progress = (REQUIRED.length - missing.length) / REQUIRED.length;
      const newStatus = complete ? 'SUBMITTED' : 'DRAFT';

      // jeśli masz kolumny status/submitted_at — zaktualizuj je spójnie
      db.query(
        'UPDATE questionnaire SET status=?, submitted_at=IF(?="SUBMITTED", NOW(), submitted_at) WHERE user_id=?',
        [newStatus, newStatus, userId],
        () => {
          return res.status(200).json({
            status: newStatus,
            progress,
            missing,
            questionnaire: q
          });
        }
      );
    });
  });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Serwer działa na http://localhost:${port}`);
});
app.get('/health', (req, res) => res.send('ok'));