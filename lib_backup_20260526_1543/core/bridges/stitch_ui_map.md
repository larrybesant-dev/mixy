PROJECT: MixVy (Desktop-first social + live interaction platform)



GOAL:

Build a desktop-first social platform combining:

\- Facebook-style social feed

\- MySpace-style profiles

\- Live audio/video rooms (Paltalk-style)

\- Speed dating feature

\- Adult/18+ gated section (strict separation)

\- Messaging system (DM + room whisper chat)



UI STYLE:

\- Dark mode default

\- Neon accents (purple, cyan, gold)

\- Glassmorphism panels

\- Mobile responsive BUT desktop prioritized

\- Left sidebar navigation + central feed + right activity panel



MAIN LAYOUT:



LEFT SIDEBAR NAV:

\- Home Feed

\- Live Rooms

\- Discover

\- Messaging

\- Friends

\- Speed Dating

\- Profile

\- Settings

\- 🔞 After Dark (locked behind age gate)



CENTER AREA:

Dynamic content depending on page:

\- Feed = posts, reels, live previews

\- Rooms = active live rooms grid

\- Messaging = chat list + active chat

\- Dating = swipe + match cards



RIGHT PANEL:

\- Online users

\- Active rooms

\- Trending posts

\- Friend suggestions



FEATURE BEHAVIOR:



FEED:

\- Infinite scroll posts

\- Like / comment / share

\- Embedded live room previews



LIVE ROOMS:

\- Join/leave instantly

\- Mic toggle

\- Stage speakers + audience

\- Raise hand system

\- Gift system



MESSAGING:

\- Real-time chat

\- Whisper mode inside rooms

\- Friend DMs



SPEED DATING:

\- Card swipe UI

\- 30–60 second matches

\- Auto next match system



AFTER DARK (18+):

\- Separate UI theme

\- Age verification gate required

\- No cross-posting to main feed

\- Separate rooms + profiles



NAVIGATION RULE:

\- No full page reloads

\- Everything is SPA-style routing

\- Desktop-first transitions



STATE RULE:

\- All updates must be real-time where possible

\- No stale UI states

\- Live presence indicators everywhere



DESIGN GOAL:

Feels like:

Facebook + MySpace + Discord + Paltalk combined

BUT cleaner and modern



IMPORTANT:

\- Keep UI modular

\- Every feature is isolated by domain

\- No cross-feature direct imports in UI layer

