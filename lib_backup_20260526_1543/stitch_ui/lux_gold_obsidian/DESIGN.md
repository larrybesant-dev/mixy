---
name: Lux Gold & Obsidian
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
  on-surface-variant: '#d0c5af'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#99907c'
  outline-variant: '#4d4635'
  surface-tint: '#e9c349'
  primary: '#f2ca50'
  on-primary: '#3c2f00'
  primary-container: '#d4af37'
  on-primary-container: '#554300'
  inverse-primary: '#735c00'
  secondary: '#fcba64'
  on-secondary: '#462a00'
  secondary-container: '#845400'
  on-secondary-container: '#ffd199'
  tertiary: '#e2ce84'
  on-tertiary: '#3a3000'
  tertiary-container: '#c5b26b'
  on-tertiary-container: '#514406'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffe088'
  primary-fixed-dim: '#e9c349'
  on-primary-fixed: '#241a00'
  on-primary-fixed-variant: '#574500'
  secondary-fixed: '#ffddb6'
  secondary-fixed-dim: '#fcba64'
  on-secondary-fixed: '#2a1800'
  on-secondary-fixed-variant: '#643f00'
  tertiary-fixed: '#f7e296'
  tertiary-fixed-dim: '#dac67d'
  on-tertiary-fixed: '#221b00'
  on-tertiary-fixed-variant: '#534608'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353534'
typography:
  headline-xl:
    fontFamily: Noto Serif
    fontSize: 48px
    fontWeight: '700'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Noto Serif
    fontSize: 32px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Noto Serif
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
    letterSpacing: '0'
  body-lg:
    fontFamily: Manrope
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
    letterSpacing: 0.01em
  body-md:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Manrope
    fontSize: 12px
    fontWeight: '700'
    lineHeight: '1'
    letterSpacing: 0.15em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 8px
  container-max: 1280px
  gutter: 24px
  margin: 32px
  stack-sm: 1rem
  stack-md: 2rem
  stack-lg: 4rem
---

## Brand & Style

The design system is defined by a sense of nocturnal prestige and kinetic luxury. It targets an elite audience that values exclusivity, high-end craftsmanship, and the art of the "after-dark" lifestyle. The brand personality is sophisticated yet dynamic, moving away from static luxury into a more fluid, modern expression of wealth.

The visual style is a hybrid of **Minimalism** and **Glassmorphism**. It utilizes vast areas of obsidian space to allow metallic elements to breathe, while employing translucent, frosted layers to create depth. To maintain "Kinetic" energy, the system uses light-leaks, gold-tinted blurs, and sharp, sweeping curves inspired by the fluid motion found in high-end mixology.

## Colors

The palette is strictly nocturnal. The primary **Metallic Gold** is not a flat fill but a multi-tonal asset that shifts between highlights and deep ochre shadows. The surface is a true **Obsidian Black**, providing a high-contrast stage for the gold accents. 

Accent colors are used sparingly as "glows" (diffused radial gradients) to simulate light reflecting off polished surfaces. High-gloss finishes are represented by the brighter gold peaks, while functional UI elements utilize the deeper gold tones to maintain legibility without distracting from the primary focus.

## Typography

This design system employs a high-contrast typographic pairing. Headlines use **Noto Serif**, chosen for its authoritative and elegant presence that mirrors the logo’s sophisticated serif style. These should be treated as editorial elements with tighter tracking in larger sizes.

Functional UI text and long-form body copy use **Manrope**. Its modern, balanced geometric shapes provide a clean counterpoint to the serif headings, ensuring the interface remains usable and professional. Labels and overlines are frequently set in uppercase with wide letter-spacing to reinforce a premium, branded feel.

## Layout & Spacing

The layout philosophy follows a **Fixed Grid** approach for web experiences to maintain an intentional, gallery-like composition. On mobile, the system transitions to a fluid model with generous margins.

The spacing rhythm is airy. Large vertical "stack" increments are used to separate distinct content blocks, creating a sense of luxury through whitespace (or "blackspace"). Elements should never feel crowded; the system prioritizes "breathing room" to emphasize the value of each piece of content.

## Elevation & Depth

Depth in the design system is achieved through **Glassmorphism** rather than traditional drop shadows. Surfaces appear as layers of smoked glass or obsidian tiles.

1.  **Base Layer:** Solid #000000.
2.  **Surface Layer:** Semi-transparent obsidian (#0D0D0D at 80% opacity) with a high-intensity background blur (20px - 40px).
3.  **Edge Treatment:** Components feature a 1px "inner glow" or "rim light" on their top and left borders using a faint gold gradient to simulate light catching a sharp edge.
4.  **Kinetic Glow:** Focused interactive elements emit a soft, golden radial glow behind them, suggesting they are backlit or luminous.

## Shapes

The shape language is precise and architectural. A **Soft** roundedness (0.25rem) is used for most UI components to maintain a modern, "cut stone" feel without appearing overly friendly or "bubbly." 

Larger containers and cards use `rounded-lg` (0.5rem) to provide just enough softness to the obsidian layers. The system avoids circles and extreme rounding, preferring the stability of sharp lines and subtle radiuses that mimic high-end product design and luxury packaging.

## Components

### Buttons
Primary buttons utilize the **Gold Metallic Gradient**. Text is rendered in obsidian black for maximum contrast. Secondary buttons are "Ghost" style with a 1px gold border and a subtle hover glow.

### Cards
Cards are built using the Glassmorphism rules: a deep obsidian fill with a 1px gold rim-light on the top edge. On hover, the background blur intensity increases, and the gold rim light brightens.

### Inputs
Input fields are dark and recessed, using a 1px stroke that transitions from neutral grey to gold when focused. The cursor and selection highlight should always use the primary gold.

### Chips & Tags
Small, pill-shaped elements used for categorization. These feature a low-opacity gold fill (10-15%) with high-contrast gold text, ensuring they are visible but subordinate to primary actions.

### Kinetic Accents
Incorporate "Star-flare" icons or micro-animations at the corners of high-value components (like a 'Premium' card) to mirror the sparkling energy of the original logo.