const assert = require("node:assert/strict");
const {describe, it} = require("node:test");

const {
  recordOperationalSignalHandler,
  sanitizeOperationalMetadata,
} = require("../index.js").__testing;

describe("operational launch signals", () => {
  it("accepts an allowlisted authenticated signal", async () => {
    const result = await recordOperationalSignalHandler({
      auth: {uid: "signal-user-1"},
      data: {
        code: "launch_messaging_freshness",
        result: "slow_ack",
        metadata: {latency_ms: 6000},
      },
    });

    assert.deepEqual(result, {accepted: true});
  });

  it("rejects unknown signal codes", async () => {
    await assert.rejects(
      recordOperationalSignalHandler({
        auth: {uid: "signal-user-2"},
        data: {code: "arbitrary_event"},
      }),
      (error) => error.code === "invalid-argument",
    );
  });

  it("requires authentication for protected operational signals", async () => {
    await assert.rejects(
      recordOperationalSignalHandler({
        data: {code: "launch_rtc_recovery_exhausted"},
        rawRequest: {ip: "127.0.0.1"},
      }),
      (error) => error.code === "unauthenticated",
    );
  });

  it("bounds and normalizes metadata", () => {
    const sanitized = sanitizeOperationalMetadata({
      "unsafe key": "x".repeat(200),
      nested: {secret: true},
    });

    assert.equal(sanitized.unsafe_key.length, 120);
    assert.equal(sanitized.nested, "[object Object]");
  });
});