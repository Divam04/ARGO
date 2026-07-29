# Design System — ARGO
### Smart Parcel & Lost-and-Found Pickup, Gate-1 · Plaksha University

> **Assumption stated up front:** the branded screenshot (color palette + pickup card) names the product "ARGO" and ties it to Gate-1, Plaksha University — which matches the parcel/lost-and-found system already in scope. This doc is written for that product. Flag it if the name or scope is off and I'll adjust.
>
> Synthesized from: the original video-derived design.md (home-services reference, confirmed against Image 2), a shipping/tracking app (Image 1), a utilitarian property-management app (Image 3), a service-booking app (Image 4), and the ARGO brand palette + pickup card (Image 5 — this is the authoritative color source).

---

## 1. Design Philosophy

**Functional, clean, utilitarian — and yet glamorous.** The reference point is a kraft-paper shipping label elevated into a digital product: postal ink stamps, manifest typography, rack-and-shelf logistics data, made to feel considered rather than purely operational. Two things do the "glamorous" work without adding decoration:

1. **A dark, gallery-like stage.** Cream/paper cards float on a near-black canvas (Image 5) instead of sitting in a flat white app shell — the same trick a physical product shot uses.
2. **A verification seal.** The circular "VERIFIED" badge reads like a wax stamp or postal cancellation mark. It turns a mundane data point (face-match %) into a moment of polish, and it's the one motif worth reusing everywhere trust needs to be communicated.

Everything else — lists, scans, filters, forms — should stay plain, dense, and fast, borrowing directly from utilitarian logistics/property apps (Images 1, 3, 4) rather than inventing new chrome.

**Comparable references:** shipment-tracking apps (AfterShip, Parcel), postal/kraft packaging branding, boutique hotel keycard/concierge UI (for the seal + card treatment).

---

## 2. Color System

The palette below is taken directly from the brand reference (Image 5); two tokens are estimated to fill functional gaps (dark canvas, alert state) since they weren't in the original swatch set.

| Token | Name | Hex | Usage | Confidence |
|---|---|---|---|---|
| `--color-kraft` | Kraft Brown | `#A97C50` | Icon marks, ID footer bars, primary accent borders | Given |
| `--color-navy` | Postal Navy | `#2E4A63` | Verification states, links, seal badge, "verified" text | Given |
| `--color-cream` | Paper Cream | `#F4EDDE` | Card/surface background (the "paper" the app sits on) | Given |
| `--color-tan` | Twine Tan | `#C9AD82` | Secondary surfaces, muted tags, "in progress" states | Given |
| `--color-ink` | Ink | `#2B2621` | Primary text on cream surfaces | Given |
| `--color-canvas` | Canvas (dark) | `#18140F` | App shell background in dark mode — cards float on this | Estimated, medium |
| `--color-alert` | Rust / Uncollected | `#9C4A3D` | Pending/overdue/uncollected status text | Estimated, medium |

**No green exists in this palette on purpose** — don't reach for it for "success" states. Use Postal Navy for verified/complete, Twine Tan for neutral/in-progress, Rust for anything needing attention.

**Palette mood:** warm neutrals (kraft, tan, cream) doing the "paper and string" work, with one cool anchor (navy) for trust/verification, and near-black for staging. Nothing saturated, nothing playful — every color reads as material, not decoration.

---

## 3. Typography

Three roles, not two — this system needs a wordmark/display voice, a body voice, and a *manifest* voice for codes and IDs.

| Role | Font | Example use | Notes |
|---|---|---|---|
| Display / Wordmark | **Inter Tight** or **Space Grotesk**, Bold | "ARGO" logotype, large stat numerals (`98.6%`) | Tight tracking, confident, geometric |
| UI / Body | **Inter**, Regular/Medium | Body copy, buttons, form labels | Same as prior doc — no change needed |
| Eyebrow / Micro-label | Inter, Medium, **uppercase**, wide tracking | `GATE-1 · PLAKSHA UNIVERSITY`, `FACE MATCH`, `STATUS` | 0.08-0.12em letter-spacing — this is the postal-stamp signature detail |
| Manifest / Code | **IBM Plex Mono** or **JetBrains Mono** | Tracking IDs (`ARGO-20260427-0091`), rack/shelf codes | Tabular figures, gives scannable data a "logged" feel |

| Element | Size | Weight | Line Height |
|---|---|---|---|
| Display / Logotype | 32-40px | 700 | 1.1 |
| Stat numeral | 28-36px | 700 | 1.1 |
| H1 (screen title) | 24-28px | 700 | 1.2 |
| Body | 15-16px | 400 | 1.5 |
| Eyebrow/label | 11-12px | 500, uppercase | 1.3 |
| Manifest/code | 13-14px | 500 (mono) | 1.4 |

---

## 4. Layout & Spacing — two densities

This product needs both a **dense operational mode** (lists, scan results) and a **spacious moment mode** (the pickup card, verification). Don't average them into one spacing scale — declare both.

```css
/* Compact - lists, filters, scan flows (Image 1 pattern) */
--space-compact-xs: 4px;
--space-compact-sm: 8px;
--space-compact-md: 12px;
--space-compact-lg: 16px;

/* Spacious - hero cards, verification moments (Image 5 pattern) */
--space-spacious-sm: 16px;
--space-spacious-md: 24px;
--space-spacious-lg: 32px;
--space-spacious-xl: 48px;
```

- **Compact mode:** tight vertical rhythm, list rows ~12-16px internal padding, minimal whitespace between items.
- **Spacious mode:** the pickup card and its stat tiles get generous internal padding (~24-32px) — this is where the "glamorous" feeling lives; don't compress it to match list density.

---

## 5. Components

Organized by actual app moment, with the screenshot that informed each.

### 5.1 Scan-In (Image 1 — Box Scan)
Camera view, full-bleed, with a corner-bracket viewfinder frame centered over the subject (parcel label or QR code). Instruction copy sits below the frame in body text. Bottom control row: gallery-import icon (left), large circular shutter button (center, filled dark), flash toggle (right). Needs both a light and dark presentation — same layout, inverted surface color, since Image 1 shows both.

### 5.2 Identity / Pickup Card (Image 5 — flagship component)
This is the signature screen. Cream card on dark canvas:
- Icon mark (outlined box glyph, kraft-brown stroke) + wordmark + eyebrow subtitle (`GATE-1 · PLAKSHA UNIVERSITY`)
- **Verification seal**, top-right: circular outline badge, two-line uppercase text (`VERIFIED` / `GATE-1`), navy stroke
- Two stat tiles side-by-side below the header: label (eyebrow style) + large value (`Verified · 98.6%` in navy, `Uncollected · 48 hrs` in rust)
- Footer bar, full-width, solid kraft/tan fill: location code left-aligned (`RACK A-03 · SHELF 3`), tracking ID right-aligned in manifest mono type

### 5.3 Shipment/Parcel List (Image 1 — My Shipping)
- Search bar (pill, rounded) with an integrated scan-icon button to its right
- Filter tabs as pill chips (`All Package / Transit / On Process / Delivered`), active state solid-fill dark
- List row: circular thumbnail, ID + item name, status pill (top-right), horizontal dotted **journey tracker** with checkmark/truck icons marking progress, from/to location + date row beneath, small package illustration on the far right
- Recolor status pills using the ARGO palette instead of neutral gray: Navy = verified/collected, Tan = in transit/processing, Rust = pending/uncollected

### 5.4 Scan Result Sheet (Image 1 — Barcode Scan Result)
Bottom sheet, rounded top corners (~28px radius), slides up over the camera view. Contains one list-row-style item summary plus a single full-width solid CTA pill (`See Details`) pinned at the bottom.

### 5.5 Report Lost Item (adapted from Image 3's maintenance-request pattern)
Reuses the "what's broken?" chip-selector pattern for lost-item categories instead: a question header, then multi-select tag chips (e.g. category types) with a `+ Add custom` affordance for anything not listed. Pair with the Scan-In camera component (5.1) for photo capture of the item.

### 5.6 Filters & Sort (Image 3)
Radio-button list for sort order, priority toggle at the top, single full-width solid CTA (`Apply`) pinned to the bottom of the sheet — same footprint as the scan result sheet for consistency.

### 5.7 Category / Service Grid (Images 2 & 4)
Icon tiles (rounded-square, ~64px) with label beneath; active state gets a filled kraft or navy background with the icon inverted to cream. Use for gate/location selection or request-type selection.

### 5.8 Stepper & Step Flow (Image 3)
Quantity stepper: `- value +` in a pill container, for anything counted (items reported, packages held). Multi-step flows get a persistent `Step 1/2` label paired with a `Next` pill button, bottom-anchored.

### 5.9 Buttons
- **Primary CTA:** solid fill (kraft or navy depending on context), pill or 12-14px rounded-rect, white/cream label text
- **Secondary/outline:** thin border in the same hue, transparent fill — used paired with primary in dual-CTA rows (Image 2's `View Details` / `Book Now` pattern)
- **FAB:** solid circular, used sparingly (e.g. "Report an item")

---

## 6. Iconography & Imagery

- **Icon style:** outline, ~2px stroke, consistent with Lucide/Phosphor — matches the box-glyph mark in the ARGO logo.
- **Custom mark:** an outlined box/package icon as the core brand glyph (seen in Image 5) — reuse it as a loading state, empty state, and app icon anchor.
- **Photography:** minimal to none. This product is data/status-driven, not marketplace/browse-driven (unlike Images 2 & 4) — lean on icons, illustration, and the seal motif rather than lifestyle photography. Where a photo is unavoidable (item report, package condition), keep it small and framed inside a card, never full-bleed hero.

---

## 7. Motion & Interaction

| Property | Value |
|---|---|
| Standard transition | Smooth, ease-out, ~200-300ms |
| Easing curve | `cubic-bezier(0, 0, 0.2, 1)` |
| Verification success | Seal badge "stamps down" — brief scale-in (0.9 to 1.0) with a slight overshoot, ~250ms. This is the one moment worth a custom animation. |
| List/scroll | Standard fade + slight upward stagger on entrance |
| Sheet presentation | Slide up from bottom, ease-out, ~300ms |

---

## 8. Light & Dark Mode

Dark is the primary, brand-defining mode (per Image 5); light is a secondary/operational mode (per Image 1) for high-glare, fast-scan contexts (e.g. using the scanner outdoors at the gate).

```css
/* Dark - default, brand-forward */
--surface-canvas-dark: #18140F;
--surface-card-dark: #F4EDDE;   /* cream card floats on dark canvas */
--text-on-card-dark: #2B2621;
--text-on-canvas-dark: #F4EDDE;

/* Light - operational */
--surface-canvas-light: #FAFAF8;
--surface-card-light: #FFFFFF;
--text-on-card-light: #2B2621;
--border-light: #E0DDD5;
```

---

## 9. Design Tokens (CSS Custom Properties)

```css
:root {
  /* Color - brand */
  --color-kraft: #A97C50;
  --color-navy: #2E4A63;
  --color-cream: #F4EDDE;
  --color-tan: #C9AD82;
  --color-ink: #2B2621;
  --color-canvas: #18140F;
  --color-alert: #9C4A3D;

  /* Typography */
  --font-display: 'Inter Tight', 'Space Grotesk', sans-serif;
  --font-body: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
  --font-mono: 'IBM Plex Mono', 'JetBrains Mono', monospace;

  --font-size-display: 36px;
  --font-size-h1: 26px;
  --font-size-body: 16px;
  --font-size-eyebrow: 12px;
  --font-size-code: 14px;
  --tracking-eyebrow: 0.1em;

  /* Spacing - compact */
  --space-compact-xs: 4px;
  --space-compact-sm: 8px;
  --space-compact-md: 12px;
  --space-compact-lg: 16px;

  /* Spacing - spacious */
  --space-spacious-sm: 16px;
  --space-spacious-md: 24px;
  --space-spacious-lg: 32px;
  --space-spacious-xl: 48px;

  /* Radius */
  --radius-pill: 999px;
  --radius-card: 20px;
  --radius-sheet-top: 28px;
  --radius-tile: 14px;

  /* Motion */
  --ease-out: cubic-bezier(0, 0, 0.2, 1);
  --duration-fast: 150ms;
  --duration-base: 250ms;
  --duration-sheet: 300ms;
}
```

---

## 10. Component -> Inspiration Map

| Component | Source | Key pattern borrowed |
|---|---|---|
| Identity/Pickup Card | Image 5 (ARGO) | Seal badge, stat tiles, manifest footer bar |
| Color palette | Image 5 (ARGO) | Kraft/Navy/Cream/Tan/Ink — authoritative |
| Scan-In camera UI | Image 1 | Viewfinder brackets, bottom control row, light+dark variants |
| Parcel list + journey tracker | Image 1 | Status pill, dotted progress tracker, search+scan bar |
| Scan Result sheet | Image 1 | Bottom sheet with pinned CTA |
| Report Lost Item chips | Image 3 | Tag/chip multi-select with "+ Add custom" |
| Filters & sort sheet | Image 3 | Radio list + pinned "Apply" CTA |
| Stepper / step flow | Image 3 | `- value +` control, `Step 1/2` + Next |
| Category/service grid | Images 2, 4 | Icon tile grid with active-fill state |
| Dual CTA button row | Image 2 | Outline + solid button pairing |

---

## 11. Open Questions / Verify Before Build

- [ ] Confirm product name is ARGO and scope is Gate-1 parcel + lost-and-found (stated assumption above)
- [ ] Exact dark-canvas and rust/alert hex values (both estimated, not sourced)
- [ ] Whether light mode is genuinely needed or dark-only is acceptable for v1
- [ ] Confirm display/mono font choices against any existing brand guidelines
- [ ] Accessibility contrast check for Ink-on-Cream and Cream-on-Canvas combos before final build
