const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {
  buildDatingProfile,
  distanceBetweenKm,
  isCompatiblePair,
  normalizeGender,
  normalizeAge,
  haversineKm,
} = require("../dating_matching");

describe("normalizeGender", () => {
  it("maps trans variants onto the matching gender", () => {
    assert.equal(normalizeGender("Trans woman"), "Woman");
    assert.equal(normalizeGender("Trans man"), "Man");
    assert.equal(normalizeGender(" woman "), "Woman");
  });

  it("returns null for prefer-not-to-say and invalid input", () => {
    assert.equal(normalizeGender("Prefer not to say"), null);
    assert.equal(normalizeGender(undefined), null);
    assert.equal(normalizeGender(42), null);
  });
});

describe("normalizeAge", () => {
  it("accepts integer ages in range only", () => {
    assert.equal(normalizeAge(25), 25);
    assert.equal(normalizeAge(17), null);
    assert.equal(normalizeAge(25.5), null);
    assert.equal(normalizeAge(Number.NaN), null);
    assert.equal(normalizeAge(Infinity), null);
  });
});

describe("haversineKm", () => {
  it("measures a known distance", () => {
    const km = haversineKm(40.7128, -74.006, 34.0522, -118.2437);
    assert.ok(km > 3900 && km < 4000, `expected ~3940km, got ${km}`);
  });

  it("uses the short path across the international date line", () => {
    const km = haversineKm(0, 179.9, 0, -179.9);
    assert.ok(km > 20 && km < 25, `expected ~22km, got ${km}`);
  });
});

describe("buildDatingProfile", () => {
  it("defaults to any gender, age 18-99, and no distance limit", () => {
    const profile = buildDatingProfile({}, undefined);
    assert.deepEqual(profile.lookingFor, []);
    assert.equal(profile.minAge, 18);
    assert.equal(profile.maxAge, 99);
    assert.equal(profile.maxDistanceKm, null);
  });

  it("drops invalid option values and non-finite coordinates", () => {
    const profile = buildDatingProfile(
      {gender: "Man", age: 30},
      {
        lookingFor: ["Woman", "Alien"],
        race: "Martian",
        maxDistanceKm: 0,
        latitude: Number.NaN,
        longitude: 500,
      },
    );
    assert.deepEqual(profile.lookingFor, ["Woman"]);
    assert.equal(profile.race, null);
    assert.equal(profile.maxDistanceKm, null);
    assert.equal(profile.latitude, null);
    assert.equal(profile.longitude, null);
  });

  it("accepts any distance from 1 to 500 km, rounded to 2 decimals", () => {
    const pick = (maxDistanceKm) =>
      buildDatingProfile({gender: "Man"}, {maxDistanceKm}).maxDistanceKm;
    assert.equal(pick(1), 1);
    assert.equal(pick(16.09344), 16.09);
    assert.equal(pick(160.9344), 160.93);
    assert.equal(pick(500), 500);
    assert.equal(pick(501), null);
    assert.equal(pick(0.5), null);
    assert.equal(pick("25"), null);
  });

  it("keeps maxAge at or above minAge", () => {
    const profile = buildDatingProfile({}, {minAge: 40, maxAge: 30});
    assert.equal(profile.minAge, 40);
    assert.equal(profile.maxAge, 40);
  });
});

describe("isCompatiblePair", () => {
  it("matches when both sides accept each other", () => {
    const alex = buildDatingProfile(
      {gender: "Man", age: 30},
      {lookingFor: ["Woman"], minAge: 25, maxAge: 35},
    );
    const sam = buildDatingProfile(
      {gender: "Woman", age: 28},
      {lookingFor: ["Man"], minAge: 25, maxAge: 40},
    );
    assert.equal(isCompatiblePair(alex, sam), true);
  });

  it("rejects when one side's gender preference excludes the other", () => {
    const alex = buildDatingProfile({gender: "Man", age: 30}, {lookingFor: ["Woman"]});
    const jordan = buildDatingProfile({gender: "Man", age: 30}, {});
    assert.equal(isCompatiblePair(alex, jordan), false);
  });

  it("rejects when the candidate's age is outside the viewer's range", () => {
    const viewer = buildDatingProfile({gender: "Man"}, {minAge: 30, maxAge: 40});
    const young = buildDatingProfile({gender: "Woman", age: 22}, {});
    assert.equal(isCompatiblePair(viewer, young), false);
  });

  it("rejects when the candidate is outside the other side's preferred race", () => {
    const viewer = buildDatingProfile({gender: "Man"}, {preferredRaces: ["Asian"]});
    const other = buildDatingProfile({gender: "Woman"}, {race: "White"});
    assert.equal(isCompatiblePair(viewer, other), false);
  });

  it("treats missing or private values as compatible", () => {
    const viewer = buildDatingProfile({gender: "Man"}, {lookingFor: ["Woman"]});
    const unknown = buildDatingProfile({gender: "Prefer not to say"}, {race: null});
    assert.equal(isCompatiblePair(viewer, unknown), true);
  });

  it("enforces distance only when both sides have a location", () => {
    const nyc = {latitude: 40.7128, longitude: -74.006};
    const nearby = {latitude: 40.73, longitude: -74.0};
    const la = {latitude: 34.0522, longitude: -118.2437};
    const viewer = buildDatingProfile({gender: "Man"}, {maxDistanceKm: 10, ...nyc});
    const near = buildDatingProfile({gender: "Woman"}, nearby);
    const far = buildDatingProfile({gender: "Woman"}, la);
    const noLocation = buildDatingProfile({gender: "Woman"}, {});
    assert.equal(isCompatiblePair(viewer, near), true);
    assert.equal(isCompatiblePair(viewer, far), false);
    assert.equal(isCompatiblePair(viewer, noLocation), true);
  });
});

describe("distanceBetweenKm", () => {
  it("returns null when either side has no location", () => {
    const a = buildDatingProfile({}, {latitude: 1, longitude: 1});
    const b = buildDatingProfile({}, {});
    assert.equal(distanceBetweenKm(a, b), null);
  });

  it("returns a rounded distance when both sides have a location", () => {
    const a = buildDatingProfile({}, {latitude: 0, longitude: 0});
    const b = buildDatingProfile({}, {latitude: 0, longitude: 0.1});
    const km = distanceBetweenKm(a, b);
    assert.equal(typeof km, "number");
    assert.ok(Math.abs(km - 11.1) < 0.2);
  });
});
