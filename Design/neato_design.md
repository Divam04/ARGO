# Design System — [Product Name]

> Derived from frame-by-frame analysis of the website demo video. Color values, type scale, and spacing are estimates from visual inspection — verify against source files (Figma/CSS) before final implementation where precision matters (checkout flows, accessibility contrast, etc.).

## 1. Design Philosophy

A modern, clean SaaS aesthetic built for a home-services / scheduling product. It reads as professional and trustworthy rather than playful, with a distinctive nature-inspired brand color (deep forest green) that breaks from typical "tech blue" conventions. Generous whitespace and soft, rounded shapes keep it approachable.

**Comparable references:** Airbnb, TaskRabbit, modern home-service platforms.

---

## 2. Color System

| Token | Hex | Usage | Confidence |
|---|---|---|---|
| `--color-primary` | `#004D25` | Hero backgrounds, section backgrounds, primary brand identity | High |
| `--color-accent` | `#FF8C33` | Primary CTAs, active states, service card highlights | High |
| `--color-background` | `#F9F7F2` | Base page background (light sections) | High |
| `--color-text-primary` | `#1A1A1A` | Headings, body text | High |
| `--color-text-secondary` | `#666666` | Descriptive/supporting text | Medium |
| `--color-border` | `#E0E0E0` | Card boundaries, dividers | Medium |
| `--color-success` | `#28A745` | Status indicators (e.g. scheduling checkmarks) | Medium |

**Palette mood:** Professional, trustworthy, nature-inspired. Dark green anchors brand moments; cream/off-white keeps content sections light and airy; orange is reserved for action and emphasis only — not decorative.

---

## 3. Typography

**Font family:** Sans-serif, geometric. Closest identifiable match: **Inter** or **Circular Std**. Recommend `Inter` as the implementation font (free, open-source, near-identical geometry).

```css
font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
```

| Element | Size | Weight | Line Height | Letter Spacing |
|---|---|---|---|---|
| H1 | 48–64px | 700 (Bold) | 1.1–1.2 | Slightly tight |
| H2 | 32px | 700 (Bold) | 1.2 | Slightly tight |
| Body | 16px | 400 (Regular) | 1.5 | Normal |
| Supporting/label | 14px | 500 (Medium) | 1.5 | Normal |

**Weights in use:** 400 (Regular), 500 (Medium), 700 (Bold).

---

## 4. Layout & Spacing

- **Grid:** Centered single-column container, not a full multi-column grid.
- **Container width:** Constrained/readable, generous side margins — not full-bleed.
- **Section rhythm:** Large vertical gaps between sections, approx. **80–120px**.
- **Alignment pattern:** Left-aligned text blocks paired with right-aligned imagery/device mockups (classic feature-row layout).

Suggested spacing scale (4px base unit, inferred from generous whitespace observed):

```css
--space-1: 4px;
--space-2: 8px;
--space-3: 16px;
--space-4: 24px;
--space-5: 32px;
--space-6: 48px;
--space-7: 80px;
--space-8: 120px;
```

---

## 5. Components

### Buttons
- Shape: **Fully rounded / pill** (`border-radius: 999px`)
- Primary: solid orange fill (`--color-accent`), white text
- Likely secondary/ghost variant not clearly visible — recommend outline style using `--color-primary` for consistency, to verify against source

### Cards / Panels
- Border-radius: ~**24px**
- Subtle drop shadow for elevation
- Light background, thin border (`--color-border`)

### Form Inputs
- Search bars: rounded corners (pill or large radius, consistent with button language)

### Navigation Bar
- **Sticky**, transparent background (likely transitions to solid on scroll — verify)

### Badges / Status Pills
- Small, fully rounded
- Used for status text (e.g. "Scheduled"), paired with `--color-success`

### Imagery Frames
- Device/product mockups carry subtle drop shadows for depth

---

## 6. Iconography & Imagery

- **Illustration style:** Flat, vector-based, clean, minimal detail
- **Icon style:** Outline icons, ~2px consistent stroke weight — closest match **Lucide** or **Phosphor** icon sets
- **Imagery treatment:** Subtle shadows on mockups/devices rather than hard borders

---

## 7. Motion & Interaction

| Property | Value |
|---|---|
| Transition style | Smooth, ease-out |
| Easing curve | `cubic-bezier(0, 0, 0.2, 1)` (ease-out: fast start, slow finish) |
| Scroll animations | Staggered card entrance + fade-in on scroll |
| Page/section transitions | Smooth vertical scroll, no hard cuts |

---

## 8. Responsive Strategy

- Demo only shows desktop/tablet — no mobile breakpoints captured on video.
- Layout is modular (feature rows, cards) and should collapse to a **single stacked column** on mobile.
- **Action item:** confirm actual mobile breakpoints and nav pattern (likely hamburger menu) with source files or a live site inspection, since none were observable in the recording.

---

## 9. Design Tokens (CSS Custom Properties)

```css
:root {
  /* Color */
  --color-primary: #004D25;
  --color-accent: #FF8C33;
  --color-background: #F9F7F2;
  --color-text-primary: #1A1A1A;
  --color-text-secondary: #666666;
  --color-border: #E0E0E0;
  --color-success: #28A745;

  /* Typography */
  --font-family-base: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
  --font-size-h1: 56px;
  --font-size-h2: 32px;
  --font-size-body: 16px;
  --font-size-label: 14px;
  --line-height-tight: 1.15;
  --line-height-body: 1.5;

  /* Spacing */
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 16px;
  --space-4: 24px;
  --space-5: 32px;
  --space-6: 48px;
  --space-7: 80px;
  --space-8: 120px;

  /* Radius */
  --radius-pill: 999px;
  --radius-card: 24px;

  /* Motion */
  --ease-out: cubic-bezier(0, 0, 0.2, 1);
  --duration-fast: 150ms;
  --duration-base: 300ms;
}
```

---

## 10. Open Questions / Verify Before Build

- [ ] Exact hex values (all colors currently estimated from video, not sampled from source)
- [ ] Secondary/ghost button style
- [ ] Nav bar solid-state on scroll behavior
- [ ] Mobile breakpoint layout and nav pattern
- [ ] Confirm font is actually Inter/Circular Std vs. a licensed alternative
