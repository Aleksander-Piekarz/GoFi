const express = require("express");
const { db } = require("../lib/db");
const { auth } = require("../middleware/auth");
const router = express.Router();
const bcrypt = require('bcryptjs');

const REQUIRED = [
  'age','weight','height','gender','goal','motivation','experience',
  'activityLevel','sleepHours','workType','availableDays','sessionLength'
];
const isMissing = (v) => v === null || v === undefined || (typeof v === 'string' && v.trim() === '');
const norm = (v) => (v === undefined || v === null || (typeof v === 'string' && v.trim() === '')) ? null : v;


// GET /users/:id/questionnaire
router.get('/:id/questionnaire', (req, res) => {
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
        progress,
        missing,
        questionnaire: q
      });
    }
  );
});

// PUT /users/:id/questionnaire
router.put('/:id/questionnaire', (req, res) => {
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

    db.query('SELECT * FROM questionnaire WHERE user_id=? LIMIT 1', [userId], (err2, rows) => {
      if (err2) return res.status(500).json({ error: 'Błąd serwera' });
      const q = rows[0];

      const missing = REQUIRED.filter(k => isMissing(q[k]));
      const complete = missing.length === 0;
      const progress = (REQUIRED.length - missing.length) / REQUIRED.length;
      const newStatus = complete ? 'SUBMITTED' : 'DRAFT';

      db.query(
        'UPDATE questionnaire SET status=?, submitted_at=IF(?="SUBMITTED", NOW(), submitted_at) WHERE user_id=?',
        [newStatus, newStatus, userId],
        () => res.status(200).json({ status: newStatus, progress, missing, questionnaire: q })
      );
    });
  });
});

// POST /users/:id/questionnaire/submit
router.post('/:id/questionnaire/submit', (req, res) => {
  const userId = req.params.id;
  db.query('SELECT * FROM questionnaire WHERE user_id=? LIMIT 1', [userId], (err, rows) => {
    if (err) return res.status(500).json({ error: 'Błąd serwera' });
    if (rows.length === 0) return res.status(404).json({ error: 'Brak ankiety' });

    const q = rows[0];
    const missing = REQUIRED.filter(k => isMissing(q[k]));
    if (missing.length > 0) {
      return res.status(400).json({ error: 'Ankieta niekompletna', missing });
    }

    db.query(
      'UPDATE questionnaire SET status="SUBMITTED", submitted_at=NOW() WHERE user_id=?',
      [userId],
      (err2) => {
        if (err2) return res.status(500).json({ error: 'Błąd serwera' });
        res.json({ message: 'Wysłano ankietę' });
      }
    );
  });
});

router.put('/me/settings', auth(true), (req, res) => {
  const { unitSystem, notifEnabled } = req.body ?? {};
  const allowedUnits = ['metric','imperial'];

  const fields = [];
  const values = [];

  if (unitSystem && allowedUnits.includes(unitSystem)) {
    fields.push('unit_system=?');
    values.push(unitSystem);
  }
  if (typeof notifEnabled === 'boolean') {
    fields.push('notif_enabled=?');
    values.push(notifEnabled ? 1 : 0);
  }

  if (!fields.length) {
    return res.status(400).json({ error: 'Brak poprawnych pól do aktualizacji' });
  }

  values.push(req.user.id);
  const sql = `UPDATE users SET ${fields.join(', ')} WHERE id=?`;

  db.query(sql, values, (err) => {
    if (err) return res.status(500).json({ error: 'Błąd serwera' });
    res.json({ ok: true });
  });
});

router.post('/me/change-password', auth(true), (req, res) => {
  const { currentPassword, newPassword } = req.body ?? {};
  if (!currentPassword || !newPassword) {
    return res.status(400).json({ error: 'Brak wymaganych pól' });
  }

  const q = "SELECT password FROM users WHERE id=? LIMIT 1";
  db.query(q, [req.user.id], (err, rows) => {
    if (err) return res.status(500).json({ error: 'Błąd serwera' });
    if (!rows.length) return res.status(404).json({ error: 'Użytkownik nie istnieje' });

    const hash = rows[0].password;
    const ok = bcrypt.compareSync(currentPassword, hash);
    if (!ok) return res.status(401).json({ error: 'Nieprawidłowe aktualne hasło' });

    const newHash = bcrypt.hashSync(newPassword, 10);
    db.query("UPDATE users SET password=? WHERE id=?", [newHash, req.user.id], (err2) => {
      if (err2) return res.status(500).json({ error: 'Błąd serwera' });
      res.json({ ok: true });
    });
  });
});

module.exports = router;
