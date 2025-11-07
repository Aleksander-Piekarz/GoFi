const express = require('express');
const router = express.Router();
const { auth } = require('../middleware/auth');
const ctrl = require('../controllers/questionnaireController');

router.get('/', auth(true), ctrl.getQuestions);


router.get('/answers/latest', auth(true), ctrl.getLatestAnswers);
router.post('/answers', auth(true), ctrl.saveAnswers);
router.get('/plan/latest', auth(true), ctrl.getLatestPlan);

router.post('/submit', auth(true), ctrl.submitAnswers);

module.exports = router;
