# MixVy Beta Tester Guide

## Welcome MessageModel (copy & send to testers)

---

> **Subject: You're invited to test MixVy — here's how to get started 🎉**
>
> Hey [Name],
>
> You've been selected as a beta tester for **MixVy** — a social live-room app where you can host and join video rooms, speed date, chat with friends, send gifts, and more.
>
> We need your honest feedback to help us shape the final product before public launch.
>
> ---
>
> **🔗 Open the app:**
> https://mix-and-mingle-v2.web.app
>
> The app runs in your browser — no download needed. Chrome or Edge on desktop gives the best experience. Mobile browsers (Chrome/Safari) are supported but may have limited video features.
>
> **1. Create your account**
> - Tap **Sign Up** and register with your email and a password.
> - Complete your profile: add a photo, username, bio, and interests.
>
> **2. Explore the features**
> Try out as many features as you can:
> - 🏠 **Home Feed** — browse posts, react, and comment
> - 👥 **Friends** — search for users, send friend requests, and accept them
> - 💬 **messages** — start a 1:1 or group chat
> - 🎥 **Live Rooms** — create or join a live video room
> - 💘 **Speed Dating** — join a session and meet new people
> - 🔔 **Notifications** — check your notification feed
> - ⚙️ **Settings** — update privacy, audio/video, and account settings
>
> **3. Submit your feedback**
> There are two ways to give feedback:
>
> **Quick bug report:** Tap the **feedback button** (bottom of the screen) at any time to report a bug or leave a note about a specific screen.
>
> **Full checklist report:** Go to **Settings → Beta Feedback** to open the structured checklist. Mark each feature as Pass / Fail / Partial and add notes. Submit when done — it takes about 5–10 minutes.
>
> **4. Things we especially need feedback on**
> - Does the app load quickly and feel smooth?
> - Can you join and host a live video room without issues?
> - Are notifications arriving correctly?
> - Does anything look broken or confusing?
>
> **5. Known limitations (don't file these as bugs)**
> - Apple Sign In is not available in this beta.
> - Payment features (buying coins, Stripe Connect) are in test mode — no real money is charged.
>
> Thank you for helping us build something great.
>
> — The MixVy Team

---

## Admin Setup: Enabling a Beta Tester Account

Before a tester can see beta-only features (the Settings → Beta Feedback screen), their account must be tagged as a beta tester in Firestore. Do this **after** they create their account.

### Option A — Firebase Console (one-off)

1. Open the [Firebase Console](https://console.firebase.google.com/project/mix-and-mingle-v2/firestore).
2. Navigate to **Firestore → users → {uid}**.
3. Add or update the field: `betaTester: true`.

### Option B — Admin callable function (bulk or scripted)

Use the `promoteToBetaTester` Cloud Function. Call it from a trusted admin account:

```js
// From an admin session (e.g., Firebase Admin SDK or a local script)
const { initializeApp } = require('firebase-admin/app');
const { getFunctions } = require('firebase-admin/functions');

// Single user
await getFunctions().httpsCallable('promoteToBetaTester')({ uid: '<target-uid>' });

// Bulk — pass an array of UIDs
await getFunctions().httpsCallable('promoteToBetaTester')({ uids: ['uid1', 'uid2', 'uid3'] });
```

Or from the Firebase Local Emulator / Functions shell if testing locally.

### Option C — Seed script (local dev only)

```bash
node tools/seed_admin_account.js
```

This sets `betaTester: true`, `admin: true`, and a starting coin balance on the target account. Only use against the emulator or a dev project.

---

## What Gets Captured

| Channel | Where it goes | When to use |
|---------|--------------|-------------|
| Quick feedback sheet (`BetaFeedbackSheet`) | `beta_feedback` Firestore collection (top-level docs) | Instant in-context bug reports |
| Full checklist report (`BetaFeedbackScreen`) | `beta_feedback/{uid}/submissions/{autoId}` | End-of-session structured review |

### Reviewing feedback in Firestore

```
Firestore → beta_feedback
  └── {uid}
       └── submissions
            └── {autoId}  ←  checklist result per tester session
```

Top-level `beta_feedback` documents contain quick reports with fields:
`category`, `MessageModel`, `route`, `uid`, `email`, `platform`, `isWeb`, `status`, `createdAt`

Filter by `status == "new"` and sort by `createdAt DESC` using the composite index already deployed to the project.

---

## Feedback Category Quick Reference

| Category | Description |
|----------|-------------|
| `bug` | Something is broken or not working |
| `suggestion` | Feature request or improvement idea |
| `ui` | Visual/layout issue |
| `performance` | App feels slow or laggy |
| `other` | Anything else |

---

## Tester Communication Tips

- Give testers a deadline (e.g., "please submit your report by Friday").
- Ask them to focus on one or two features per session rather than everything at once.
- For critical bugs they find, ask them to note which screen they were on — the quick feedback sheet captures this automatically via the route field.
- Follow up with a short thank-you MessageModel and let them know which issues were fixed.
