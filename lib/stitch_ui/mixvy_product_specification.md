# MixVy App UI Design Specification

## Product Summary
MixVy is a modern real-time social live platform that hybrids live audio/video rooms, social discovery feeds, and Discord-style messaging.

## Core Design Principle: "Tiered Presence"
The UI must visually support a system where not everyone is on camera simultaneously:
- **Full Video (1-3 users):** Large tiles for hosts/active speakers.
- **Low Video (5-15 users):** Smaller tiles with lower priority.
- **Audio Only (Most users):** Avatars with animated waveforms.
- **Dynamic Promotion:** The UI should feel "alive" and adapt in real-time as users speak.

## Visual Style Direction
- **Primary:** Dark mode first.
- **Accents:** Neon highlights for live/active states.
- **Effects:** Soft gradients, optional glassmorphism for panels.
- **Motion:** Smooth animations for speaker transitions and motion clarity.

## Pages to Design

### 1. Home / Discovery Feed
- **Layout:** Vertical scroll feed (TikTok style).
- **Content:** Room title, host avatar, viewer count, active speaker previews.
- **Features:** "LIVE NOW" section at the top.

### 2. Live Room Page (Core Experience)
- **Top:** Room info, viewer count, connection status.
- **Main Stage:** Dynamic grid supporting Full Video, Low Video, and Audio-Only states with speaking indicators.
- **Controls:** Mic, camera, leave, raise hand, reactions.

### 3. Messaging (DM System)
- **Layout:** Desktop-style list on left, chat on right.
- **Features:** Real-time messages, media sharing, lightweight UI.

### 4. Profile Page
- **Layout:** Banner, avatar, stats (followers/following), history (hosted/joined), badges/roles.
- **Tone:** Creator-focused.

### 5. Search Page
- **Features:** Search bar, categorized results (Rooms, People, Topics).

## Technical & UX Constraints
- **Performance:** Support 100+ users without rendering 100 active videos.
- **Graceful Degradation:** Seamless transitions between video and avatar fallbacks.
- **Complexity Hiding:** Hide the technical tiered switching behind a natural social interface.