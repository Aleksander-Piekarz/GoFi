const express = require("express");
const cors = require("cors");
require("dotenv").config();

const { db } = require("./lib/db");
const authRoutes = require("./routes/auth");
const userRoutes = require("./routes/users");

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.use('/api/exercises', require('./routes/exercises'));

// prosty log
app.use((req, _res, next) => { console.log(`${req.method} ${req.url}`); next(); });

// healthcheck
app.get("/health", (_req, res) => res.send("ok"));


app.use("/api/users", userRoutes);

// tymczasowe przekierowania (zachowują metodę POST)
app.post("/register", (req, res) => res.redirect(307, "/auth/register"));
app.post("/login", (req, res) => res.redirect(307, "/auth/login"));

app.use('/api/auth', require('./routes/auth'));
app.use('/api/questionnaire', require('./routes/questionnaire'));

// 404 – pokaż co faktycznie było wołane
app.use((req, res) => {
  res.status(404).json({error:'Not found', method:req.method, url:req.originalUrl});
});

app.listen(port, "0.0.0.0", () => {
  console.log(`API listening on http://10.10.0.1:${port}`);
});
