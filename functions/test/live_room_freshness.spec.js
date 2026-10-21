const test = require("node:test");
const assert = require("node:assert/strict");
const {
  ACTIVE_PARTICIPANT_WINDOW_MS,
  applyFreshParticipantCounts,
} = require("../live_room_freshness");

test("active window is 90 seconds", () => {
  assert.equal(ACTIVE_PARTICIPANT_WINDOW_MS, 90 * 1000);
});

test("drops rooms with no fresh participants and uses fresh counts", () => {
  const rooms = [
    {id: "stale", participantCount: 17, memberCount: 17},
    {id: "live", participantCount: 2, memberCount: 2},
    {id: "failed", participantCount: 5, memberCount: 5},
  ];
  const fresh = new Map([["stale", 0], ["live", 3]]);

  const result = applyFreshParticipantCounts(rooms, fresh, 20);

  assert.deepEqual(result.map((r) => r.id), ["live"]);
  assert.equal(result[0].participantCount, 3);
  assert.equal(result[0].memberCount, 3);
});

test("ranks by fresh count and applies the limit", () => {
  const rooms = [
    {id: "a", participantCount: 99},
    {id: "b", participantCount: 99},
    {id: "c", participantCount: 99},
  ];
  const fresh = new Map([["a", 4], ["b", 9], ["c", 1]]);

  const result = applyFreshParticipantCounts(rooms, fresh, 2);

  assert.deepEqual(result.map((r) => r.id), ["b", "a"]);
});

test("does not mutate input rooms", () => {
  const rooms = [{id: "a", participantCount: 7}];
  applyFreshParticipantCounts(rooms, new Map([["a", 1]]), 20);
  assert.equal(rooms[0].participantCount, 7);
});
