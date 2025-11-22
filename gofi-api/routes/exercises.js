const express = require('express');
const router = express.Router();
const { auth } = require('../middleware/auth');

const { pool } = require('../lib/db'); 

router.get('/search', auth(true), async (req,res) => {
  const { pattern, muscle, equip, loc } = req.query;
  const where = [];
  const args = [];
  
  if (pattern) { where.push('pattern=?'); args.push(pattern); }
  
  if (muscle)  { 
    where.push('(primary_muscle = ? OR FIND_IN_SET(?, secondary_muscles))'); 
    args.push(muscle, muscle); 
  }
  if (equip)   { where.push('FIND_IN_SET(?, equipment)'); args.push(equip); }
  if (loc)     { where.push('FIND_IN_SET(?, location)'); args.push(loc); }

  const sql = `SELECT code,name,primary_muscle,pattern,equipment,location,difficulty FROM exercises` +
              (where.length ? ` WHERE ${where.join(' AND ')}` : '') + ` LIMIT 100`;
  
  
  const [rows] = await pool.promise().query(sql, args);
  res.json(rows);
});

module.exports = router;