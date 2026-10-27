"use strict";

const GENDER_OPTIONS = ["Woman", "Man", "Non-binary"];
const RACE_OPTIONS = [
  "Asian",
  "Black",
  "Hispanic/Latino",
  "Middle Eastern",
  "Mixed",
  "South Asian",
  "White",
  "Other",
];
const SEXUALITY_OPTIONS = [
  "Straight",
  "Gay",
  "Lesbian",
  "Bisexual",
  "Pansexual",
  "Queer",
  "Asexual",
  "Other",
];
const MIN_DISTANCE_KM = 1;
const MAX_DISTANCE_KM = 500;
const MIN_AGE = 18;
const MAX_AGE = 99;

const GENDER_ALIASES = {
  woman: "Woman",
  "trans woman": "Woman",
  man: "Man",
  "trans man": "Man",
  "non-binary": "Non-binary",
};

function normalizeGender(raw) {
  if (typeof raw !== "string") return null;
  return GENDER_ALIASES[raw.trim().toLowerCase()] || null;
}

function normalizeAge(raw) {
  if (typeof raw !== "number" || !Number.isFinite(raw)) return null;
  if (!Number.isInteger(raw) || raw < MIN_AGE || raw > MAX_AGE) return null;
  return raw;
}

function normalizeCoordinate(raw, limit) {
  if (typeof raw !== "number" || !Number.isFinite(raw)) return null;
  if (raw < -limit || raw > limit) return null;
  return raw;
}

function filterOptions(values, allowed) {
  if (!Array.isArray(values)) return [];
  return values.filter((value) => allowed.includes(value));
}

function pickOption(value, allowed) {
  return allowed.includes(value) ? value : null;
}

function pickDistanceKm(raw) {
  if (typeof raw !== "number" || !Number.isFinite(raw)) return null;
  if (raw < MIN_DISTANCE_KM || raw > MAX_DISTANCE_KM) return null;
  return Math.round(raw * 100) / 100;
}

function clampAge(raw, fallback) {
  if (typeof raw !== "number" || !Number.isFinite(raw)) return fallback;
  return Math.min(MAX_AGE, Math.max(MIN_AGE, Math.round(raw)));
}

/**
 * Builds a matching profile from the public user document and the owner-only
 * dating preferences. Missing values stay null or empty, which means "any".
 */
function buildDatingProfile(publicData, privateData) {
  const pub = publicData || {};
  const priv = privateData || {};
  const minAge = clampAge(priv.minAge, MIN_AGE);
  const maxAge = Math.max(minAge, clampAge(priv.maxAge, MAX_AGE));
  return {
    gender: normalizeGender(pub.gender),
    age: normalizeAge(pub.age),
    race: pickOption(priv.race, RACE_OPTIONS),
    sexuality: pickOption(priv.sexuality, SEXUALITY_OPTIONS),
    lookingFor: filterOptions(priv.lookingFor, GENDER_OPTIONS),
    minAge,
    maxAge,
    maxDistanceKm: pickDistanceKm(priv.maxDistanceKm),
    preferredRaces: filterOptions(priv.preferredRaces, RACE_OPTIONS),
    preferredSexualities: filterOptions(priv.preferredSexualities, SEXUALITY_OPTIONS),
    latitude: normalizeCoordinate(priv.latitude, 90),
    longitude: normalizeCoordinate(priv.longitude, 180),
  };
}

function haversineKm(lat1, lon1, lat2, lon2) {
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.min(1, Math.sqrt(a)));
}

/** Distance in km rounded to 1 decimal, or null when either side has no location. */
function distanceBetweenKm(a, b) {
  if (a.latitude === null || b.latitude === null) return null;
  if (a.longitude === null || b.longitude === null) return null;
  const km = haversineKm(a.latitude, a.longitude, b.latitude, b.longitude);
  return Math.round(km * 10) / 10;
}

/**
 * Whether `viewer`'s preferences accept `other`. Unknown values on `other`
 * (missing gender, age, race, or location) are not treated as a mismatch.
 */
function acceptsProfile(viewer, other) {
  if (
    viewer.lookingFor.length > 0 &&
    other.gender !== null &&
    !viewer.lookingFor.includes(other.gender)
  ) {
    return false;
  }
  if (
    other.age !== null &&
    (other.age < viewer.minAge || other.age > viewer.maxAge)
  ) {
    return false;
  }
  if (
    viewer.preferredRaces.length > 0 &&
    other.race !== null &&
    !viewer.preferredRaces.includes(other.race)
  ) {
    return false;
  }
  if (
    viewer.preferredSexualities.length > 0 &&
    other.sexuality !== null &&
    !viewer.preferredSexualities.includes(other.sexuality)
  ) {
    return false;
  }
  if (viewer.maxDistanceKm !== null) {
    const km = distanceBetweenKm(viewer, other);
    if (km !== null && km > viewer.maxDistanceKm) return false;
  }
  return true;
}

function isCompatiblePair(a, b) {
  return acceptsProfile(a, b) && acceptsProfile(b, a);
}

module.exports = {
  GENDER_OPTIONS,
  RACE_OPTIONS,
  SEXUALITY_OPTIONS,
  MIN_DISTANCE_KM,
  MAX_DISTANCE_KM,
  MIN_AGE,
  MAX_AGE,
  normalizeGender,
  normalizeAge,
  buildDatingProfile,
  haversineKm,
  distanceBetweenKm,
  acceptsProfile,
  isCompatiblePair,
};
