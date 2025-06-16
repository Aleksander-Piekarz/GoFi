
const express = require("express");
const mysql = require("mysql2");
const bodyParser = require("body-parser");
const cors = require("cors");
require("dotenv").config();
const app = express();
const port = 3000;

app.use(cors());
app.use(bodyParser.json());

// Połączenie z bazą danych
const db = mysql.createConnection({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  port: 3306,
});

db.connect(err => {
  if (err) {
    console.log("Błąd połączenia z bazą:", err);
  } else {
    console.log("Połączono z bazą MySQL!");
  }
});

// Rejestracja użytkownika
app.post("/register", (req, res) => {
  const {  email,username, password } = req.body;
  const query = "INSERT INTO users ( email,username, password) VALUES (?, ?, ?)";

  db.query(query, [email, username, password], (err, result) => {
    if (err) {
      console.log("Błąd zapisu:", err);
      return res.status(500).json({ error: "Błąd serwera" });
    }
    res.json({ message: "Użytkownik zarejestrowany!" });
  });
});

// Logowanie użytkownika
app.post("/login", (req, res) => {
  const { email, password } = req.body;

  const query = "SELECT * FROM users WHERE email = ? AND password = ?";
  db.query(query, [email, password], (err, results) => {
    if (err) {
      console.log("Błąd zapytania:", err);
      return res.status(500).json({ error: "Błąd serwera" });
    }

    if (results.length === 0) {
      return res.status(401).json({ error: "Nieprawidłowy login lub hasło" });
    }

    res.json({ message: "Zalogowano pomyślnie", user: results[0] });
  });
});

app.listen(port, () => {
  console.log(`Serwer działa na http://localhost:${port}`);
});
