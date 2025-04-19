const express = require("express");
const mysql = require("mysql2");
const bodyParser = require("body-parser");
const cors = require("cors");

const app = express();
const port = 3000;

app.use(cors());
app.use(bodyParser.json());

// Połączenie z bazą danych
const db = mysql.createConnection({
  host: "sql7.freesqldatabase.com",
  user: "sql7774037",
  password: "K11j9XVmNb",
  database: "sql7774037",
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
  const { username, email, password } = req.body;
  const query = "INSERT INTO users (username, email, password) VALUES (?, ?, ?)";

  db.query(query, [username, email, password], (err, result) => {
    if (err) {
      console.log("Błąd zapisu:", err);
      return res.status(500).send("Błąd serwera");
    }
    res.send("Użytkownik zarejestrowany!");
  });
});

app.listen(port, () => {
  console.log(`Serwer działa na http://localhost:${port}`);
});
