// A room counts as live only while at least one participant has a heartbeat
// (lastActiveAt) inside this window. Participant heartbeats run every 20 s.
const ACTIVE_PARTICIPANT_WINDOW_MS = 90 * 1000;

// freshCountsById: roomId -> number of participants with a fresh heartbeat.
// Rooms missing from the map (count lookup failed) are dropped.
function applyFreshParticipantCounts(rooms, freshCountsById, limit) {
  return rooms
    .map((room) => {
      const fresh = freshCountsById.get(room.id) ?? 0;
      return {...room, participantCount: fresh, memberCount: fresh};
    })
    .filter((room) => room.participantCount > 0)
    .sort((a, b) => b.participantCount - a.participantCount)
    .slice(0, limit);
}

module.exports = {ACTIVE_PARTICIPANT_WINDOW_MS, applyFreshParticipantCounts};
