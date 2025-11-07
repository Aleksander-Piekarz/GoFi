const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const { db } = require("../lib/db");
const { auth } = require('../middleware/auth');
const router = express.Router();

// POST /auth/register
router.post("/register", (req, res) => {
  const { email, username, password } = req.body ?? {};
  if (!email || !username || !password) {
    return res.status(400).json({ error: "Brak wymaganych pól" });
  }
  const sel = "SELECT id FROM users WHERE email=? LIMIT 1";
  db.query(sel, [email], (e, rows) => {
    if (e) return res.status(500).json({ error: "Błąd serwera" });
    if (rows.length) return res.status(409).json({ error: "Email zajęty" });

    const hash = bcrypt.hashSync(password, 10);
    const ins = "INSERT INTO users (username,email,password) VALUES (?,?,?)";
    db.query(ins, [username, email, hash], (err, result) => {
      if (err) return res.status(500).json({ error: "Błąd serwera" });
      const userId = result.insertId;
      const token = jwt.sign({ sub: userId, role: "free" }, process.env.JWT_SECRET, { expiresIn: "7d" });
      res.json({ message: "Użytkownik zarejestrowany", token, user: { id: userId, email, username, role: "free" } });
    });
  });
});

// POST /auth/login
router.post("/login", (req, res) => {
  const { email, password } = req.body ?? {};
  if (!email || !password) return res.status(400).json({ error: "Brak wymaganych pól" });

  const q = "SELECT id, username, email, password, role FROM users WHERE email=? LIMIT 1";
  db.query(q, [email], (err, rows) => {
    if (err) return res.status(500).json({ error: "Błąd serwera" });
    if (!rows.length) return res.status(401).json({ error: "Nieprawidłowy login lub hasło" });

    const u = rows[0];
    const ok = bcrypt.compareSync(password, u.password);
    if (!ok) return res.status(401).json({ error: "Nieprawidłowy login lub hasło" });

    const token = jwt.sign(
  { sub: u.id, email: u.email, username: u.username || null, role: u.role || 'user' },
  process.env.JWT_SECRET,
  { expiresIn: '7d' }
  );
  console.log("JWT:", token);
res.json({ message: "Zalogowano", token, user: { id: u.id, email: u.email, username: u.username, role: u.role || "free" } });
  });
});

router.get('/me', auth(true), (req, res) => {
  const q = "SELECT id, username, email, role, unit_system, notif_enabled FROM users WHERE id=? LIMIT 1";
  db.query(q, [req.user.id], (err, rows) => {
    if (err) return res.status(500).json({ error: "Błąd serwera" });
    if (!rows.length) return res.status(404).json({ error: "Użytkownik nie istnieje" });

    const u = rows[0];
    res.json({
      id: u.id,
      email: u.email,
      username: u.username,
      role: u.role,
      unitSystem: u.unit_system || 'metric',
      notifEnabled: !!u.notif_enabled,
    });
  });
});

module.exports = router;
