# MixVy Soft-Launch Rollout Plan

Date: 2026-04-15
Status: Ready to execute

## Objective

Validate real-user feel, session stability, and recovery behavior with a small trusted cohort before broader release.

## Launch Rule

Proceed only if the session feels smooth to real people.

## Single Success Metric

The session is successful if no user asks:
- what is going on?

Confusion counts as failure even when nothing technically crashes.

Success is not just "no crash."
Success is:
- users can join without confusion
- host controls behave predictably
- chat, mic, and presence feel consistent
- recovery actions work when something goes wrong

## Cohort 1: Controlled Session

Invite 3 to 5 trusted testers with this mix:
- 1 desktop Chrome user
- 1 Android user
- 1 iPhone user if available
- 1 user on a different network or mobile data
- 1 backup moderator or observer

Keep the room private and time-boxed.

## Session Length

30 to 60 minutes.

## Live Test Script

### Minute 0 to 5
- everyone joins
- confirm roster, mic state, and chat are visible
- verify nobody is confused about who is in the room

### Minute 5 to 15
- normal talking
- pass the mic between users
- confirm host controls feel obvious and predictable

### Minute 15 to 25
- force chaos
- one person refreshes
- one person drops connection or switches networks
- one person rejoins

### Minute 25 to 40
- test host transfer
- run a kick and rejoin recovery test
- confirm moderator controls are instant and reliable

### Minute 40 to 60
- let the room run naturally
- do not interfere unless something breaks
- watch for confusion, hesitation, or trust loss

## What To Watch For

Capture only these categories:
- who has the mic confusion
- missing user presence or delayed visibility
- chat delay or disappearing state
- audio confusion or unexpected mute behavior
- any moment that feels awkward, unclear, or off

If a tester says "that felt weird," treat it as a valid bug.

## Roles During Session

### Host
- runs the room normally
- does not narrate every action

### Backup moderator
- can end the room or remove a disruptive user if needed

### Observer
- takes notes with exact time, user device, and what felt wrong
- avoids interrupting unless recovery is needed

## Safety Net Before Public Opening

Confirm all three are ready:
- room can be ended immediately
- a user can be removed or contained quickly
- the team knows how to recover and restart if the room gets weird

## Stop Conditions

If something breaks, end the session immediately.
Do not try to test through it.

Do not widen rollout if any of these happen:
- repeated join confusion
- incorrect host authority or mic ownership
- users disappear or duplicate in a way people notice
- chat or audio state becomes unreliable
- recovery tools do not work fast enough

## Go Decision After Cohort 1

Advance only if:
- no critical failures occur
- no unresolved user-confusing behavior remains
- at least one reconnect and one rejoin succeed cleanly
- host safety controls work under pressure

## Growth Plan

### Phase 1
- private invite only
- 3 to 5 testers
- one room at a time

### Phase 2
- 10 to 20 trusted users
- limited time window
- monitor for repeated confusion patterns

### Phase 3
- wider soft launch
- keep moderation and recovery coverage active

## After The Session

Ask every tester these exact three questions:
1. Did anything feel confusing?
2. Did you ever not know what was happening?
3. If this was a real app, would you trust it?

If any answer is hesitant, do not expand yet.

Within the same day:
1. list every weird moment
2. fix only user-facing friction or safety issues
3. rerun one short validation session
4. then expand gradually

## Bottom Line

The product is now beyond infrastructure hardening.

The release gate is real human feel.
