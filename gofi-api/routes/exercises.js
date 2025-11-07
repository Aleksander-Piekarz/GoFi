const express = require('express');
const router = express.Router();
const { auth } = require('../middleware/auth');
const mysql = require('mysql2/promise');
const pool = mysql.createPool({ host:process.env.DB_HOST, user:process.env.DB_USER, password:process.env.DB_PASS, database:process.env.DB_NAME });

router.get('/search', auth(true), async (req,res) => {
  const { pattern, muscle, equip, loc } = req.query;
  const where = [];
  const args = [];
  if (pattern) { where.push('pattern=?'); args.push(pattern); }
  if (muscle)  { where.push('muscle_group=?'); args.push(muscle); }
  if (equip)   { where.push('FIND_IN_SET(?, equipment)'); args.push(equip); }
  if (loc)     { where.push('FIND_IN_SET(?, location)'); args.push(loc); }

  const sql = `SELECT code,name,muscle_group,pattern,equipment,location,difficulty FROM exercises` +
              (where.length ? ` WHERE ${where.join(' AND ')}` : '') + ` LIMIT 100`;
  const [rows] = await pool.query(sql, args);
  res.json(rows);
});

module.exports = router;
