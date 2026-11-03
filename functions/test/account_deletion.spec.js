const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const functionsIndex = require("../index");

const {deleteCurrentUserAccountHandler} = functionsIndex.__testing;

function requestFor(uid, authTime) {
  return {
    data: {},
    auth: uid ? {
      uid,
      token: {auth_time: authTime},
    } : null,
  };
}

describe("account deletion", () => {
  it("requires authentication", async () => {
    await assert.rejects(
        deleteCurrentUserAccountHandler(requestFor(null, null)),
        (error) => error.code === "unauthenticated",
    );
  });

  it("requires a recent sign-in", async () => {
    await assert.rejects(
        deleteCurrentUserAccountHandler(requestFor("user-1", 600), {
          now: () => 1000 * 1000,
        }),
        (error) =>
          error.code === "failed-precondition" &&
          error.details?.reason === "requires-recent-login",
    );
  });

  it("cleans user data before deleting the Auth account", async () => {
    const calls = [];

    const result = await deleteCurrentUserAccountHandler(
        requestFor("user-1", 900),
        {
          now: () => 1000 * 1000,
          cleanup: async (uid) => calls.push(`cleanup:${uid}`),
          auth: {
            deleteUser: async (uid) => calls.push(`auth:${uid}`),
          },
        },
    );

    assert.deepEqual(calls, ["cleanup:user-1", "auth:user-1"]);
    assert.deepEqual(result, {deleted: true});
  });

  it("keeps the Auth account when data cleanup fails", async () => {
    let authDeleted = false;

    await assert.rejects(
        deleteCurrentUserAccountHandler(
            requestFor("user-1", 900),
            {
              now: () => 1000 * 1000,
              cleanup: async () => {
                throw new Error("cleanup failed");
              },
              auth: {
                deleteUser: async () => {
                  authDeleted = true;
                },
              },
            },
        ),
        /cleanup failed/,
    );

    assert.equal(authDeleted, false);
  });
});
