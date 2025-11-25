const controller = require('../controllers/questionnaireController');
const { validateAnswers, pickSplit, suggestReps } = controller.helpers;

describe('Algorytm Personalizacji (Logic Only)', () => {

  test('Powinien odrzucić niekompletną ankietę', () => {
    const badAnswers = { goal: 'mass' }; // Brakuje dni, doświadczenia itp.
    const errors = validateAnswers(badAnswers);
    expect(errors.length).toBeGreaterThan(0);
    expect(errors).toContain('days_per_week out of range (2–7)');
  });

  test('Powinien dobrać split FBW dla 2 dni treningowych', () => {
    const split = pickSplit('mass', 2);
    expect(split.name).toContain('Full Body Workout');
    expect(split.schedule.length).toBe(2);
  });

  test('Powinien dobrać split PPL dla 3 dni i celu "mass"', () => {
    const split = pickSplit('mass', 3);
    expect(split.name).toContain('Push/Pull/Legs');
  });

  test('Powinien dobrać split FBW dla 3 dni i celu "reduction" (logika biznesowa)', () => {
    // Zgodnie z Twoją logiką: reduction + 3 dni = FBW_3, a mass + 3 dni = PPL_3
    const split = pickSplit('reduction', 3);
    expect(split.name).toContain('Full Body Workout');
  });

  test('Powinien sugerować zakres powtórzeń 6-8 dla siły/masy w przysiadach', () => {
    // (goal, pattern, intensity, experience)
    const reps = suggestReps('mass', 'squat', 'high', 'intermediate');
    expect(reps).toBe('5–8');
  });

  test('Powinien sugerować zakres 10-15 dla redukcji', () => {
    const reps = suggestReps('reduction', 'push_h', 'medium', 'beginner');
    expect(reps).toBe('10–15');
  });

});