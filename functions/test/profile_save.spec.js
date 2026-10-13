const assert = require("node:assert/strict");
const {test} = require("node:test");
const admin = require("firebase-admin");
const express = require("express");
const request = require("supertest");
const {saveProfile} = require("../index");

test("saveProfile creates a missing user profile with merge semantics", async () => {
  const firestore = admin.firestore();
  const auth = admin.auth();
  const originalBatch = firestore.batch;
  const originalCollection = firestore.collection;
  const originalVerify = auth.verifyIdToken;
  const writes = new Map();

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
    set: (ref, data, options) => {
      writes.set(ref.path, {data, options});
    },
    commit: async () => {},
  });
  auth.verifyIdToken = async () => ({uid: "tester"});

  try {
    const app = express();
    app.use(express.json());
    app.post("/", saveProfile);
    const response = await request(app)
      .post("/")
      .set("Authorization", "Bearer test-token")
      .send({userData: {username: "Tester"}});

    assert.equal(response.status, 200);
    const identity = writes.get("users/tester");
    assert.equal(identity.data.uid, "tester");
    assert.equal(identity.data.id, "tester");
    assert.equal(identity.data.username, "Tester");
    assert.deepEqual(identity.options, {merge: true});
  } finally {
    firestore.batch = originalBatch;
    firestore.collection = originalCollection;
    auth.verifyIdToken = originalVerify;
  }
});
