---
name: Kinetic Noir
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#3a3939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1c1b1b'
  surface-container: '#201f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353534'
  on-surface: '#e5e2e1'
  on-surface-variant: '#ccc3da'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#958da3'
  outline-variant: '#4a4457'
  surface-tint: '#d1bcff'
  primary: '#d1bcff'
  on-primary: '#3c0090'
  primary-container: '#7000ff'
  on-primary-container: '#ddcdff'
  inverse-primary: '#7212ff'
  secondary: '#d7ffc5'
  on-secondary: '#053900'
  secondary-container: '#2ff801'
  on-secondary-container: '#0f6d00'
  tertiary: '#4cd6ff'
  on-tertiary: '#003543'
  tertiary-container: '#00647c'
  on-tertiary-container: '#89e0ff'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e9ddff'
  primary-fixed-dim: '#d1bcff'
  on-primary-fixed: '#23005b'
  on-primary-fixed-variant: '#5700c9'
  secondary-fixed: '#79ff5b'
  secondary-fixed-dim: '#2ae500'
  on-secondary-fixed: '#022100'
  on-secondary-fixed-variant: '#095300'
  tertiary-fixed: '#b7eaff'
  tertiary-fixed-dim: '#4cd6ff'
  on-tertiary-fixed: '#001f28'
  on-tertiary-fixed-variant: '#004e60'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353534'
typography:
  display:
    fontFamily: Space Grotesk
    fontSize: 48px
    fontWeight: '700'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 32px
    fontWeight: '600'
    lineHeight: '1.2'
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
  label-bold:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '600'
    lineHeight: '1.4'
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1.4'
    letterSpacing: 0.01em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 40px
  gutter: 20px
  margin: 24px
---

## Brand & Style

The design system is engineered for a high-octane social environment where real-time interaction is the core value. The brand personality is "Techno-Optimistic," "Electric," and "Premium." It targets a digital-native audience that values speed, clarity, and aesthetic sophistication. 

The visual style merges **Minimalism** with **Glassmorphism** and **High-Contrast** accents. By using a "Dark Mode First" philosophy, the design system minimizes ocular fatigue during long sessions while allowing vibrant status indicators—like "Live" moments—to pop with maximum intensity. The emotional response should be one of being at the center of a global, high-tech pulse.

## Colors

The palette is anchored in deep, obsidian blacks to create an infinite sense of depth. 
- **Primary (Electric Purple):** Used for core branding, primary actions, and active selection states.
- **Secondary (Neon Green):** Reserved exclusively for "Live" indicators, real-time updates, and success states to provide high-energy feedback.
- **Tertiary (Cyber Blue):** Used for secondary links, metadata highlights, and technical information.
- **Neutrals:** A range of grays starting from `#0D0D0D` for backgrounds to `#1A1A1A` for containers, ensuring a soft but clear hierarchy.
- **Gradients:** Active states utilize a linear gradient from Primary to Tertiary (Purple to Blue) at a 135-degree angle.

## Typography

This design system utilizes a dual-font approach to balance personality with readability. 
- **Space Grotesk** is used for headlines and display text to reinforce the futuristic, technical vibe of the platform. Its geometric quirks provide the "high-energy" signature required.
- **Inter** handles all body copy and UI labels, ensuring that high-density social feeds remain legible and functional. 

Headlines should use tighter letter-spacing to feel impactful, while metadata labels use slightly increased tracking for clarity against dark backgrounds.

## Layout & Spacing

The design system employs a **Fluid Grid** model with a base-4 spacing scale. The layout is designed to feel spacious but connected.
- **Grid:** A 12-column system for desktop, 4-column for mobile.
- **Gutter:** 20px fixed gutters to maintain breathing room between high-energy content cards.
- **Rhythm:** Vertical rhythm is strictly enforced in 8px increments to maintain motion clarity during fast scrolling.
- **Padding:** Internal container padding should default to `lg` (24px) for primary content and `md` (16px) for secondary modules.

## Elevation & Depth

Depth is achieved through **Glassmorphism** rather than traditional drop shadows.
- **Layer 0 (Base):** Deepest black `#0D0D0D`.
- **Layer 1 (Panels):** Elevated surfaces use `#1A1A1A` with a subtle 1px border of `white @ 10%` to define edges without adding bulk.
- **Layer 2 (Overlays):** Modals and flyouts use a backdrop-blur (20px to 40px) with a semi-transparent dark fill (`#1A1A1A` at 80% opacity).
- **Glows:** High-priority elements (like a "Live" card) may use a subtle, diffused outer glow matching the Secondary color (Neon Green) to simulate a physical light source emitting from the screen.

## Shapes

The design system adopts a **Rounded** shape language to soften the aggressive high-contrast colors, making the platform feel approachable. 
- **Standard Radius:** 0.5rem (8px) for small components like inputs and buttons.
- **Large Radius:** 1rem (16px) for content cards and main containers.
- **Pill Radius:** Used exclusively for tags, chips, and the "Live" indicator to distinguish them as interactive or status-based elements.

## Components

- **Buttons:** Primary buttons use a linear gradient background (Purple to Blue). Secondary buttons use a ghost style with a 1px border. All buttons have a hover state that increases the brightness of the gradient or border.
- **Glass Cards:** Used for feed items. These feature a subtle background blur and a 1px top-light stroke to simulate glass catching the light.
- **Live Indicator:** A pill-shaped chip with a Neon Green background and black text. It must include a "pulse" animation to signify real-time activity.
- **Input Fields:** Deep charcoal background with a 1px border that glows Purple when focused.
- **Status Chips:** Small, pill-shaped markers for categories or metadata, using semi-transparent fills of the brand colors.
- **Real-time Feed List:** Items are separated by a 1px transparent-white line. On-hover, the entire row should subtly lighten to `#262626`.
- **Interactive Graphs:** For social metrics, use thin, 2px stroke lines in Cyber Blue with a soft gradient fill underneath.