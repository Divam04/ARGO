# Home Services App — Design System

> Reverse-engineered from provided UI screenshots (Home, Service Timing modal, Home Care Scheduler checklist). Use this as a starting spec — exact hex values and font names are close approximations and should be fine-tuned against real assets when available.

---

## 1. Brand & Visual Language

- **Category:** Home services marketplace app (booking cleaning, painting, plumbing, electrical, remodels, etc.)
- **Tone:** Friendly, trustworthy, organic — rounded shapes, soft illustrations, warm accent color against a grounded deep-green brand color.
- **Signature motif:** Organic "blob" shapes (freeform rounded polygons) used as decorative backgrounds, in orange/green tones.

---

## 2. Color Palette

| Token | Hex (approx) | Usage |
|---|---|---|
| `--color-primary-green` | `#1C5E3E` | Header backgrounds, bottom tab bar, primary brand surfaces, podium/pedestal graphic |
| `--color-primary-green-dark` | `#134531` | Shadows/pressed states on green surfaces |
| `--color-accent-orange` | `#EB7A3C` | CTA buttons, active radio fills, icon backgrounds, checkmarks, category icon tint |
| `--color-accent-orange-light` | `#F7C99A` | Secondary blob shapes, soft icon backgrounds |
| `--color-accent-blue` | `#2F6FA8` | Bell/notification illustration accent |
| `--color-success-green-bg` | `#DCEFDD` | "Do it yourself" pill background |
| `--color-success-green-text` | `#1C5E3E` | "Do it yourself" pill text, checked checkbox fill |
| `--color-surface-white` | `#FFFFFF` | Cards, modals, search bar |
| `--color-surface-offwhite` | `#F4F4F1` | Page background, list item background, category tile background |
| `--color-border-light` | `#E7E7E3` | Card borders, dividers |
| `--color-text-primary` | `#1A1A1A` | Headings, primary body text |
| `--color-text-secondary` | `#6E6E6B` | Subtitles, placeholder text |
| `--color-text-on-green` | `#FFFFFF` | Text on green header/tab bar |
| `--color-text-on-green-muted` | `#CFE3D6` | Secondary text on green ("Hello, Lindsey!") |

---

## 3. Typography

Two-font pairing: a **rounded/serif display face** for large headings and card titles, and a **clean grotesque sans-serif** for UI text, labels, and body copy.

| Style | Font (suggested) | Weight | Size | Line height | Usage |
|---|---|---|---|---|---|
| Display / Screen Title | Poppins or a soft serif (e.g. Fraunces, Tiempos) | 700 | 28–30px | 1.2 | "Home Care Scheduler" screen titles |
| Card Title | Same as Display | 700 | 20–22px | 1.2 | Promo card titles |
| Location / Header Bold | Inter or SF Pro Rounded | 700 | 20px | 1.2 | "Boston, 02108" |
| Body / Greeting | Inter | 400 | 14px | 1.4 | "Hello, Lindsey!", subtitle text |
| Label (category tiles, list items) | Inter | 600 | 14–15px | 1.3 | "Cleaning", "Run appliance clean cycles" |
| Small pill / tag text | Inter | 600 | 11px, uppercase or title case | 1.2 | "do it yourself" |
| Input placeholder | Inter | 400 | 15px | 1.3 | "What service are you looking for?" |
| Status bar / system | SF Pro (native) | — | — | — | iOS system font, untouched |

---

## 4. Spacing & Layout

- **Base unit:** 4px grid (4 / 8 / 12 / 16 / 20 / 24 / 32)
- **Screen horizontal padding:** 20px
- **Card corner radius:** 20–24px (large, consistently rounded)
- **Small element corner radius (pills, search bar, buttons):** full pill (999px)
- **Category tile corner radius:** 16px
- **Grid gap (category tiles):** 12px
- **Section vertical spacing:** 24px between major blocks

---

## 5. Components

### 5.1 Top Header (Home screen)
- Full-width green (`--color-primary-green`) block, rounded bottom corners (~24px), extends to top safe area.
- Contains: greeting text (muted white, small), bold location line with pin icon (white), search bar below.
- **Search bar:** white pill, full width minus padding, magnifying-glass icon + light gray placeholder text, height ~48px.

### 5.2 Category Grid
- 3-column grid, 2 rows visible (6 categories: Additions & Remodels, Cleaning, Painting, Heating, Plumbing, Electrical).
- Each tile: off-white rounded square/rectangle card, icon in a small orange-tinted icon badge at top-left, label below in bold dark text, left-aligned.
- Tile padding: 16px. Icon size: ~28–32px.

### 5.3 Promo Card ("Home Care Scheduler")
- Full-width rounded card (24px radius) with a background photo (lifestyle image, e.g. patio/pool), dark gradient overlay bottom-left for text legibility.
- Bold white title (2 lines), circular orange button with white right-arrow icon in bottom-left corner of the card.

### 5.4 Bottom Tab Bar
- Floating pill-shaped bar, green background, positioned above home indicator with margin.
- 4 icons: Home (active — shown inside a white circular pill), Grid/Categories, Calendar/Bookings, Profile.
- Active state = white filled circle behind icon; inactive icons rendered in a lighter green/white outline.

### 5.5 Modal Bottom Sheet ("When do you need this work done?")
- Full-width white sheet with large top corner radius (~28px), rises from bottom over a dimmed/blurred background of the previous screen.
- Close (X) icon top-right in a light gray circular button.
- Centered illustration (bell icon: blue bell shape + orange base/sound-wave, flat 2-color icon style) above the heading.
- Heading centered, bold, 2 lines.
- Below: vertical list of 3 selectable rows (radio-style), each a full-width light-gray rounded rectangle (16px radius) with label text left-aligned and a circular radio control right-aligned (selected = orange filled circle with white checkmark; unselected = outlined light-gray circle).
- Row height ~56px, 12px gap between rows.

### 5.6 Checklist Screen ("Home Care Scheduler")
- White background, no header bar — just a filter icon (top-left, in a light rounded-square button) and a close X (top-right, same style).
- Large bold title (2-line wrap) + gray subtitle beneath.
- Vertical timeline-style list: each item is a white/off-white rounded pill row (radius ~16px, full width) containing:
  - Checkbox on the left (checked = filled green circle with white check; unchecked = empty outlined circle)
  - Task label (medium/bold text)
  - Chevron-right icon on the far right
  - A small rounded pill tag above each row reading **"do it yourself"** (light green bg, dark green text) — appears to sit centered above certain rows as a category label.
- Rows connected by a vertical dotted line running through the left side, like a timeline/roadmap.
- Bottom of screen: decorative organic blob shapes (orange, dark green, orange-light) bleeding off the bottom edge — purely decorative, no interactive content.

---

## 6. Iconography

- Style: flat, two-tone, rounded-corner line/solid icons (not skeuomorphic).
- Category icons (hammer, spray bottle, paint roller, thermometer, wrench, lightning bolt): solid orange fill on transparent/off-white badge.
- Utility icons (search, filter, close, chevron, location pin, checkmark): simple single-color line icons, dark gray or white depending on background.
- Illustration icons (bell in modal): slightly more detailed flat illustration, 2–3 colors, used only for empty-state/informational moments — not part of the standard icon set.

---

## 7. Elevation & Effects

- Cards: very subtle drop shadow (`0 4px 12px rgba(0,0,0,0.06)`) — mostly relies on flat color contrast rather than heavy shadows.
- Bottom sheet: stronger shadow separating it from dimmed background (`0 -8px 24px rgba(0,0,0,0.15)`), background screen dimmed to ~40–50% black overlay and slightly blurred.
- Tab bar: soft shadow to float it above content (`0 4px 16px rgba(0,0,0,0.15)`).

---

## 8. Screen Inventory (for build reference)

1. **Home** — Header w/ location + search, category grid (6 items), promo card, floating tab bar.
2. **Services (background/dimmed)** — Search field pre-filled ("Painting"), category grid for a sub-vertical (Paint, Decorators & ...).
3. **Timing Modal** — Bottom sheet triggered from a service flow; single-select radio list (Within 2 weeks / More than 2 weeks / Not sure – still planning).
4. **Home Care Scheduler (checklist)** — Full-screen list of DIY home-maintenance tasks with checkboxes, tags, and timeline connector; filter + close controls at top; decorative blobs at bottom.

---

## 9. Suggested Tech Notes for Rebuild

- Use a **design-token file** (JSON/CSS variables) for the palette above so light theme values are centralized.
- Build category tiles, list rows, and pills as reusable components — they repeat with only icon/label/state changes.
- The floating pill tab bar and bottom-sheet modal are the two trickiest native-feeling elements — on web, replicate with `position: fixed` + safe-area insets; on mobile, use native sheet/tab-bar components where possible for correct gesture behavior.
