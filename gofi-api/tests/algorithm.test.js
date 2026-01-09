const algorithm = require("../lib/algorithm");

const { validateAnswers, pickSplit, configureVolume } = algorithm.helpers;

describe("Algorytm Personalizacji (Logic Only)", () => {
  test("Powinien odrzucić niekompletną ankietę", () => {
    const badAnswers = { goal: "mass" };
    const errors = validateAnswers(badAnswers);

    expect(errors.length).toBeGreaterThan(0);

    expect(errors).toContain("Missing days");
  });

  test("Powinien dobrać split FBW dla 2 dni treningowych", () => {
    const split = pickSplit("mass", 2);
    expect(split.name).toContain("Full Body Workout");
    expect(split.schedule.length).toBe(2);
  });

  test('Powinien dobrać split PPL dla 3 dni i celu "mass"', () => {
    const split = pickSplit("mass", 3);
    expect(split.name).toContain("Push/Pull/Legs");
  });

  test('Powinien dobrać split FBW dla 3 dni i celu "reduction" (logika biznesowa)', () => {
    const split = pickSplit("reduction", 3);
    expect(split.name).toContain("Full Body Workout");
  });

  test("Powinien sugerować zakres powtórzeń 6-8 dla siły/masy w ćwiczeniach złożonych", () => {
    const mockCompound = {
      code: "squat",
      mechanics: "compound",
      difficulty: 3,
    };

    const result = configureVolume(mockCompound, "intermediate", "mass");

    expect(result.reps).toBe("6-8");
    expect(result.sets).toBe(4);
  });

  test("Powinien sugerować zakres 10-12 dla początkującego na redukcji", () => {
    const mockExercise = {
      code: "dummy_push",
      mechanics: "isolation",
      difficulty: 1,
    };

    const result = configureVolume(mockExercise, "beginner", "reduction");

    expect(result.reps).toBe("10-12");
  });
});

