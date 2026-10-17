const assert = require("node:assert/strict");
const {test} = require("node:test");
const admin = require("firebase-admin");
const request = require("supertest");
const express = require("express");
const {saveProfile} = require("../index");

test("saveProfile persists gallery photos and intro video with avatar and cover", async () => {
  const firestore = admin.firestore();
  const auth = admin.auth();
  const originalBatch = firestore.batch;
  const originalCollection = firestore.collection;
  const originalVerify = auth.verifyIdToken;
  const writes = new Map();
  let committed = false;
  firestore.collection = (name) => ({
    doc: (id) => ({
      path: `${name}/${id}`,
      collection: (child) => ({
        doc: (docId) => ({path: `${name}/${id}/${child}/${docId}`}),
      }),
    }),
  });
  firestore.batch = () => ({
    update: () => {
      throw new Error("saveProfile must not require an existing user document");
    },
    set: (ref, data) => writes.set(ref.path, data),
    commit: async () => { committed = true; },
  });
  auth.verifyIdToken = async () => ({uid: "tester"});
  const media = {
    avatarUrl: "https://storage.example.test/avatar.jpg",
    coverPhotoUrl: "https://storage.example.test/cover.jpg",
    galleryUrls: [
      "https://storage.example.test/gallery-1.jpg",
      "https://storage.example.test/gallery-2.jpg",
    ],
    introVideoUrl: "https://storage.example.test/intro.mp4",
  };
  try {
    const app = express();
    app.use(express.json());
    app.post("/", saveProfile);
    const response = await request(app)
      .post("/")
      .set("Authorization", "Bearer test-token")
      .send({userData: {username: "tester", ...media}});
    assert.equal(response.status, 200);
    assert.equal(response.body.success, true);
    assert.equal(committed, true);
    const identity = writes.get("users/tester");
    assert.equal(identity.uid, "tester");
    assert.equal(identity.id, "tester");
    assert.equal(identity.username, "tester");
    const profile = writes.get("profile_public/tester");
    for (const [field, value] of Object.entries(media)) {
      assert.deepEqual(profile[field], value);
    }
  } finally {
    firestore.batch = originalBatch;
    firestore.collection = originalCollection;
    auth.verifyIdToken = originalVerify;
  }
});
