# Parcel App — Build Specification

Companion to `PARCEL_APP_FLOWS.md`. Read that first for navigation; this file
is the authority on behaviour, data, and constraints.

**Source of truth:** a hand-drawn UI Framework board. Every yellow annotation on
that board is carried into this document as a hard requirement. Nothing here is
decorative.

**Revision 2.** Changes from r1: the OTP is the first step of handover, not the
third; the receiver is a distinct person from the owner and is recorded
separately; face enrolment is seeded from a supplied image database rather than
bootstrapped on first collection.

---

## 0. What this app is

A tablet app for the security desk of a single university campus (Plaksha). It
replaces the manual parcel register. Two jobs:

1. **Inbound** — a courier drops a parcel. The guard scans the label, the app
   reads the details, assigns a storage rack, records it, and emails the owner
   twice: the parcel details, and a collection code.
2. **Handover** — someone arrives with a collection code. The guard types it in;
   it identifies exactly one parcel. The guard then records **who is collecting**
   — which need not be the owner — verifies that person's face, hands the parcel
   over, and the app emails the **owner** to tell them who took it.

Plus an admin layer for guards, shelves, API keys, an email log, and a dashboard
that mirrors the existing AutoParcel web dashboard.

**The owner/receiver split is the spine of this system.** Anyone may collect a
parcel; the code is the authorisation and the receiver's UID is the audit trail.
Every design decision below follows from that.

---

## 1. Assumptions and open decisions

These were not fully determined by the board. Each is implemented as stated
below; each can be flipped with a single instruction. **Do not silently change
these — if you disagree, raise it rather than improvising.**

| ID | Decision taken | Alternative if wrong |
|---|---|---|
| **A1** | **Confirmed by the owner.** Handover is: Home -> Enter PIN -> PARCEL -> Receiver ID search -> Face Scan -> Handed Over. The OTP is entered first and resolves to one parcel. | None — this is settled. |
| **A2** | **Confirmed by the owner.** Face enrolment is seeded from a manually assembled database of images keyed by UID, imported once. Format in §9.5. | Add enrolment-on-first-collection later as a top-up for students missing from the seed set. |
| **A3** | **Confirmed by the owner.** The PIN email is sent at storage time, alongside the STORED email, as a separate message. | Send on demand instead. |
| **A4** | **Guard sign-in is Guard ID only**, exactly as drawn — no password. | Recommended hardening: add an admin-set 4-digit guard PIN. This is a shared tablet at a gate; anyone who learns a Guard ID can log parcels and release them under that guard's name. Flag to the owner before go-live. |
| **A5** | **20 racks: A1-A5, B1-B5, C1-C5, D1-D5.** 10 slots each, 200 total. | Change the count in one config constant; do not hardcode rack names across screens. |
| **A6** | The OTP is **4 digits and globally unique among uncollected parcels** — it must be, since it is entered with no other context. See §9.2 for the brute-force consequence and the mitigation. | Move to 6 digits. This is a config change plus a 6-box PIN screen. Recommended if the uncollected count ever runs high. |

---

## 2. Stack — locked

| Layer | Choice |
|---|---|
| App | **Flutter**, built as a local `.apk`, sideloaded on the tablet. Not Play Store. |
| Backend | **Firebase** — Firestore, Auth, Storage, Cloud Functions (Node.js/TypeScript), App Check |
| OCR / label reading | **Gemini 2.5 Flash** via **Vertex AI**, called only from a Cloud Function |
| Face recognition | **InsightFace** models, run **on-device** via ONNX Runtime |
| Face detection | Google ML Kit (on-device, free, ships with Flutter) |
| Email | **Resend**, called only from a Cloud Function |
| Student data | CSV import; face images via a one-off ZIP import (§9.5) |
| Scope | One campus, one tenant. Do not build multi-tenancy. |

**Do not use** Firebase Studio's App Prototyping agent (sunsetting, web-only, no
APK pipeline). Install **Firebase Agent Skills for Flutter** into your coding
agent before starting — it materially reduces Firebase hallucination.

---

## 3. Non-negotiables

These are the things a coding agent will get wrong by default. They are not open
to improvisation.

### 3.1 No secrets in the APK
An APK can be unzipped by anyone. The Vertex AI credential and the Resend key
**never** ship in the binary and **never** reach the client.

- Keys live in Firestore at `config/apiKeys`, written only by an authenticated admin.
- Firestore rules deny **all** client reads of `config/**`. Only Cloud Functions
  (admin SDK) read them.
- The app calls `scanLabel()` and never calls Vertex AI directly. Same for email.
- Enable **Firebase App Check** so only your APK can invoke the Functions.

### 3.2 The Firestore schema in §6 is fixed
Do not invent field names per screen. If a field is missing, add it to §6 first.

### 3.3 Rack capacity is exactly 10
Enforced in the Cloud Function with a transaction, not only in the UI. Two guards
on two tablets must not be able to fill slot 10 simultaneously.

### 3.4 The API key screen must not autosave
Written explicitly on the board. If the device or OS back button is pressed on
the API Key Edit screen, the new value is discarded. Only SAVE commits.

### 3.5 Owner and receiver are different fields
`studentUid` is the owner. `receiverUid` is whoever collected. Never conflate
them, never default one to the other in code. The COLLECTED email goes to the
owner and names the receiver.

---

## 4. Global behaviours

### 4.1 Loading screen
Used throughout the app wherever a wait exceeds ~300ms.
Animation: parcels falling into a shopping cart. The cart fills in proportion to
progress and is **full at 100%**. Where real progress is unknown, use an
indeterminate loop that never shows a full cart.

### 4.2 Back button
The device/OS back button mirrors the app's own back control — **but only on
screens that have a specified back control**. On every other screen the OS back
button is **disabled** and does nothing.

Screens **with** back: Guard ID (exits app), Profile, Enter PIN, PARCEL, Receiver
ID Search, Parcel Details (all variants), Settings, Email Log, Dashboard, Admin
Login, Admin Menu, Guards List, Guard Detail, Shelves, API Keys List, API Key Edit.

Screens **without** back (OS back disabled): Loading, Logged In, Scan Label
in-progress, Face Scan in-progress, Parcel Recorded, Parcel Handed Over, and all
confirmation dialogs (which dismiss via their own NO/cancel).

### 4.3 Clock and timestamps
The app reads the tablet clock; the Cloud Function stamps the authoritative
server time. Where they disagree by more than 5 minutes, show a warning banner to
the guard — a wrong tablet clock corrupts the audit trail. Every parcel carries
`loggedAt` and, once collected, `collectedAt`. Emails quote these timestamps.
Timezone: Asia/Kolkata, fixed.

### 4.4 Offline
Firestore offline persistence is on. Face matching runs on-device and works
offline. Label OCR, email sending, and PIN verification require network — when
offline, queue the parcel locally, show a clear "will sync" state, and flush on
reconnect. Never let a guard believe a parcel was recorded when it was not.

---

## 5. Screen specification

Naming: Flutter route names in `snake_case`, widget classes in `PascalCase`.

### 5.1 Loading — `LoadingScreen`
Full-bleed. Falling-parcels-into-cart animation. No controls. No back.

### 5.2 Guard ID — `GuardIdScreen`
- Single text input: **GUARD ID**. Numeric keyboard.
- Submit -> look up `guards` where `guardId == input` and `active == true`.
- Unknown or inactive ID -> inline error, field shakes, input retained.
- Success -> `LoggedInScreen`. Back = exit app.

### 5.3 Logged In — `LoggedInScreen`
- Person icon, **"{NAME} LOGGED IN"**, LOGOUT button.
- Auto-advances to Home after ~1.5s, or on tap. No back.

### 5.4 Profile — `ProfileScreen`
Reached from the green person icon on Home.
- Person icon, **"{NAME} LOGGED IN"**, **LOG OUT** button (cyan).
- Back chevron -> Home. LOG OUT -> clears session -> `GuardIdScreen`.

### 5.5 Home — `HomeScreen`
The hub. Every flow starts and ends here.

| Element | Position | Action |
|---|---|---|
| Grey asterisk | top-left | -> Settings |
| Green person icon | top-right | -> Profile |
| Search card with search icon and field | upper, large | -> **Enter PIN** (starts handover) |
| Green camera button | lower card, top half | -> Scan Label (inbound) |
| Dashed divider | lower card, middle | decorative |
| Pink **Enter Manually** button | lower card, bottom half | -> Parcel Details (BLANK) |

The search card on Home is a tap target only — it opens the OTP entry screen.
Do not implement inline search results on Home. Label its placeholder text
"Enter collection code" so the guard is never confused about what it wants.

### 5.6 Scan Label — `ScanLabelScreen`
- Live camera viewport, framing guide, **Processing** spinner while the Function runs.
- Captures a frame -> `scanLabel()` Cloud Function -> Gemini 2.5 Flash.
- **Success** -> Parcel Details (PREFILLED).
- **Failure** (no readable label, low confidence, timeout, network error) ->
  Parcel Details (BLANK) with a **"Manual Scan Unsuccessful"** header.
- Allow retry from the failure header without returning Home. No back while processing.

### 5.7 Parcel Details — `ParcelDetailsScreen`
One screen, three states: `prefilled`, `blank`, `blankAfterFailedScan`.

Fields (all editable by tapping the field directly):
1. Delivery service
2. Date of delivery — defaults to today
3. Recipient name — as printed on the label
4. Tracking / AWB number
5. Owner UID — auto-resolved from recipient name where possible, editable

**Blank state:** every field empty, showing only the field title and a **faded
example entry** as placeholder (e.g. a greyed "Blue Dart"). Placeholders must be
visually distinct from real values and must never be submitted as data.

**Prefilled state:** values from OCR, each with a subtle "scanned" marker that
disappears once the guard edits that field.

Buttons: **BACK** (red) -> Home, discards. **STORE** (green) -> tentatively
assigns a rack -> Parcel Recorded.

Validation before STORE: delivery service, date, and recipient name required.
Tracking number optional. Owner UID may be unresolved — see §9.3.

### 5.8 Parcel Recorded — `ParcelRecordedScreen`
- **PARCEL DETAILS** block — read-only summary.
- **STORAGE RACK** block — the auto-assigned rack, e.g. `B3 - slot 7`.
  - Tapping it opens the **Rack Override Picker**: racks with free slots and
    their occupancy. Required because the auto-assigned rack may already be
    physically full even if the system thinks otherwise.
- **DONE** (cyan) -> commits via `commitParcel()`, fires both emails, returns Home.
- No back. The only exits are DONE, or an explicit discard that releases the slot.

### 5.9 Enter PIN — `EnterPinScreen`  *(first step of handover)*
- Four separate boxes, Uber-style: auto-advance on entry, auto-backspace on
  delete, paste fills all four, numeric keypad, large touch targets.
- Entered **cold** — there is no student context yet. The code is matched against
  **all uncollected parcels**, and resolves to exactly one.
- No match -> inline error, boxes clear, attempt counter increments.
- **5 failed attempts -> lock this device for 10 minutes**, return Home, log the
  event with the guard's ID. The lockout is per device, not per parcel, because
  the attacker has no parcel selected. See §9.2.
- Back chevron -> Home. Success -> PARCEL.

### 5.10 PARCEL — `ParcelScreen`
Shows the single parcel the code resolved to. No selection, no ambiguity.
- **DELIVERY SERVICE**
- **DATE OF DELIVERY**
- **NAME** — the owner's name, as recorded
- Also show the storage rack, so the guard knows where to physically go.

Buttons: **BACK** (red) -> Enter PIN. **PROCEED** (green) -> Receiver ID Search.

### 5.11 Receiver ID Search — `ReceiverSearchScreen`
Titled **"Enter Student ID of receiver"**. This records **who is physically
collecting** — which may or may not be the owner. Both are normal.

Two states on one screen.

**Empty state:** search field focused, heading **Recent searches**, the last 10
UIDs looked up on this tablet.

**Typing state:** heading changes to **Suggested**. Results ranked by:
1. Prefix match on UID (strongest)
2. Prefix match on name
3. Substring match on either
4. **Then, as a tiebreaker, descending number of uncollected parcels held**

Show the parcel count as a badge on each row. Debounce 200ms. Cap at 8 results.

**Pre-select the owner** at the top of the empty state as a one-tap shortcut,
clearly labelled "Owner" — most collections are by the owner, and this saves the
guard a search without hiding the fact that someone else can be chosen.

Selecting a receiver -> Face Scan. Back chevron -> PARCEL.

### 5.12 Face Scan — `FaceScanScreen`
Verifies that the person standing there **is the receiver they just claimed to
be**. It does not check whether they are the owner.

- Live front camera, oval framing guide, **Processing** indicator.
- ML Kit detects the face; InsightFace/ONNX produces a 512-d embedding on-device;
  cosine similarity against the **selected receiver's** stored embedding.
- **Threshold 0.36 cosine distance** (tune on real data — see §10).
- **Match** -> Parcel Handed Over.
- **No match, no face detected, or the receiver has no enrolled embedding** ->
  Manual Verification.
- Give up and route to Manual Verification after 10 seconds. Never trap the guard.
- No back while processing.

### 5.13 Parcel Handed Over — `ParcelHandedOverScreen`
- **Parcel details with receiver** — parcel summary, the owner's name and UID,
  the **receiver's** name and UID, the verification method, and the timestamp.
- Where receiver != owner, show that difference prominently. The guard should
  notice it, not have to infer it.
- **Email sent** confirmation indicator, reflecting the *actual* send result.
- Returns Home automatically after ~3s or on tap. No back.

### 5.14 Manual Verification — `ManualVerificationScreen`
- Camera viewport labelled **STUDENT ID** for capturing the **receiver's** ID card.
- **RE-SHOT** (red) -> discards and re-opens ID capture.
- **VERIFY** (green) -> guard confirms the ID visually -> Parcel Handed Over.
- The captured image is stored against the parcel for audit, with the receiver's
  UID, and retained per §10 retention.

### 5.15 Settings — `SettingsScreen`
Reached from the grey asterisk on Home. A card with a notched corner containing:
- **ADMIN LOGIN** (green) -> Admin Login
- **EMAIL LOG** (cyan) -> Email Log
- **DASHBOARD** (pink) -> Dashboard

Back chevron -> Home.

### 5.16 Email Log — `EmailLogScreen`
**A log of every email the system has sent.** Read-only history — this is not a
login screen and has no credentials.

- Filter chips at top: **PIN**, **COLLECTED**, **STORED**. Multi-select; all
  active by default.
- **Scrollable** list with a visible scrollbar, newest first.
- Each row: type badge, recipient, subject, timestamp, delivery status.
- **Tapping a row expands it inline to show the email in full detail** — full
  body, parcel reference, Resend message ID, delivery/bounce status.
- Include failed and bounced sends. A bounced PIN email is why a student turns up
  without a code, and the guard needs to be able to see that.
- Back chevron -> Settings.

### 5.17 Dashboard — `DashboardScreen`
Mirrors the existing AutoParcel dashboard. Required elements:
- **Total Parcels** (large primary tile)
- **Collected Parcels**
- **Uncollected Parcels**
- **Average days taken to collect parcel this month**
- **Daily Parcel Intake** bar chart, Sunday -> Saturday
- **Download Excel** and **Download page** buttons

Add two tiles AutoParcel does not have, because this system can produce states it
cannot: **Unmatched parcels** (§9.3) and **Collected by someone other than the
owner** (this month). Colour treatment on AutoParcel is teal on white; match it
loosely so the two systems read as one product. Back chevron -> Settings.

### 5.18 Admin Login — `AdminLoginScreen`
- Person icon, **USERNAME** field, **PASSWORD** field.
- **Verify the credentials and give a visible indication of whether they were
  correct or not** — not a silent failure. Distinguish "wrong credentials" from
  "no network".
- Success -> Admin Menu. Back chevron -> Settings.
- Backed by Firebase Auth. Rate-limit to 5 attempts per minute per device.

### 5.19 Admin Menu — `AdminMenuScreen`
Three buttons: **GUARDS** (pink), **SHELVES** (cyan), **API KEYS** (red).
Back chevron -> Settings, and ends the admin session.

### 5.20 Guards List — `GuardsListScreen`
- Scrollable stack of guard placards, each showing a guard icon, **GUARD NAME**
  and **GUARD ID**.
- **Tapping an individual placard opens Guard Detail.**
- Include an "Add guard" affordance (not on the board, but the list is
  unmaintainable without it — flagged as an addition).
- Back chevron -> Admin Menu.

### 5.21 Guard Detail — `GuardDetailScreen`
- Guard icon, **GUARD NAME**, **GUARD ID**.
- **CHANGE DETAILS** (cyan) -> confirmation dialog, **asks for the admin
  password**, and on success **returns to the previous page**.
- **DELETE GUARD** (red) -> confirmation dialog, **asks for the admin password**,
  and on success **returns to the previous page**.
- Deletion is a soft delete: set `active: false`, retain the record. Parcels
  logged by that guard must keep a valid guard reference forever.
- Back chevron -> Guards List.

### 5.22 Shelves — `ShelvesScreen`
- **Animated visual representation of the racks**, **scrollable**, so the admin
  can edit any rack's name.
- Racks labelled **A1, C1, D2 ...**; show occupancy per rack (e.g. 7/10) with a
  fill animation.
- **Renaming a rack pulls up a confirmation dialog.**
- **BACK saves progress** and returns to the preceding page — the opposite of the
  API key screen. Pending renames are committed on back.
- Renaming changes the display label only; the internal rack ID never changes, so
  historical parcel records stay valid.

### 5.23 API Keys List — `ApiKeysListScreen`
- Back chevron top-left.
- One row per key. First row labelled **GEMINI API**, value **masked**
  (`........`) with an **EDIT** control. Further rows for every other key the app
  uses (Resend, and any others added).
- Never display a full key. Show at most the last 4 characters.
- Back chevron -> Admin Menu.

### 5.24 API Key Change Confirmation — `ApiKeyChangeConfirmDialog`
- Text: **"ARE YOU SURE YOU WANT TO CHANGE THE GEMINI API KEY?"** (substitute the
  relevant key name).
- **NO** (red) -> back to API Keys List, no change.
- **YES** (green) -> API Key Edit.

### 5.25 API Key Edit — `ApiKeyEditScreen`
- Title = key name. Masked input field.
- **SAVE** (cyan) -> writes the key, returns to API Keys List.
- **BACK** (purple) -> returns to API Keys List, **discards**.
- **DO NOT AUTOSAVE. Even if the device/OS back button is pressed, the new API
  key must not be saved.** Hold the value in local state only; write to Firestore
  exclusively in the SAVE handler.

### 5.26 Bulk Face Enrolment — `BulkEnrolScreen`  *(one-off, not on the board)*
Hidden behind a long-press on the Admin Menu title. Used once at setup, and
occasionally after that for new intakes.

- Select a ZIP from the tablet's storage (format in §9.5).
- Progress list: per UID, one of `enrolled`, `no face detected`,
  `multiple faces`, `UID not in student list`, `image unreadable`.
- Runs the **identical on-device pipeline** used by Face Scan. This is the point
  of doing it in-app — see §9.5.
- Exportable failure report so the owner knows which photos to re-take.

---

## 6. Data model — Firestore

```
students/{uid}
  uid: string              // e.g. "U02180160"
  name: string
  email: string
  nameLower: string        // for search
  faceEmbedding: number[]  // 512-d, null until enrolled
  faceEnrolledAt: timestamp | null
  faceSource: "seed_import" | "manual" | null
  parcelsWaiting: number   // denormalised, maintained by Functions, used for ranking
  createdAt: timestamp

guards/{docId}
  guardId: string          // the ID typed on the login screen
  name: string
  active: boolean
  createdAt: timestamp

racks/{rackId}             // rackId = "A1", "B3", ... immutable
  label: string            // display name, admin-editable
  capacity: number         // 10
  occupied: number
  order: number

parcels/{parcelId}
  deliveryService: string
  dateOfDelivery: timestamp
  recipientNameRaw: string // exactly as scanned
  trackingNumber: string | null
  studentUid: string | null      // THE OWNER
  rackId: string
  slotIndex: number              // 1..10
  status: "stored" | "collected"
  pinHash: string                // SHA-256, never store the plaintext PIN
  loggedByGuardId: string
  loggedAt: timestamp            // server time

  // handover
  receiverUid: string | null         // WHO ACTUALLY COLLECTED
  receiverIsOwner: boolean | null    // derived at write time, stored for reporting
  collectedByGuardId: string | null
  collectedAt: timestamp | null
  verificationMethod: "face" | "manual_id" | null
  faceMatchScore: number | null
  idCapturePath: string | null       // Storage path, manual verification only
  ocrConfidence: number | null

pinAttempts/{deviceId}     // brute-force control, see 9.2
  failedCount: number
  lockedUntil: timestamp | null
  lastGuardId: string
  updatedAt: timestamp

emails/{emailId}
  type: "PIN" | "STORED" | "COLLECTED"
  to: string
  subject: string
  bodyHtml: string
  parcelId: string
  studentUid: string       // the owner - always the addressee
  sentAt: timestamp
  resendId: string | null
  status: "queued" | "sent" | "failed" | "bounced"
  error: string | null

config/apiKeys             // CLIENT READ DENIED
  gemini: string
  resend: string
  updatedAt: timestamp
  updatedBy: string

config/app
  faceMatchThreshold: number   // default 0.36
  rackCapacity: number         // 10
  pinLength: number            // 4
  pinMaxAttempts: number       // 5
  pinLockoutMinutes: number    // 10
```

### Security rules — shape

```
match /config/{doc}      { allow read, write: if false; }   // Functions only
match /students/{uid}    { allow read: if isSignedIn(); allow write: if false; }
match /parcels/{id}      { allow read: if isSignedIn(); allow write: if false; }
match /guards/{id}       { allow read: if isSignedIn(); allow write: if isAdmin(); }
match /racks/{id}        { allow read: if isSignedIn(); allow write: if isAdmin(); }
match /emails/{id}       { allow read: if isSignedIn(); allow write: if false; }
match /pinAttempts/{id}  { allow read, write: if false; }
```

All parcel mutations go through Cloud Functions. The client never writes a parcel.
`students.faceEmbedding` must not be readable in bulk by the client — expose it
via a callable that returns one embedding for one requested UID, so a stolen APK
cannot exfiltrate the whole biometric set.

---

## 7. Cloud Functions

| Function | Type | Does |
|---|---|---|
| `scanLabel` | callable | Takes a base64 image. Reads the Gemini key from `config/apiKeys`. Calls Gemini 2.5 Flash on Vertex AI with a strict JSON-only prompt. Returns `{deliveryService, dateOfDelivery, recipientName, trackingNumber, confidence}`. |
| `assignRack` | callable | Transaction. Finds the first rack with `occupied < capacity` in display order. Returns a tentative `{rackId, slotIndex}` with a 5-minute hold. |
| `commitParcel` | callable | Transaction. Writes the parcel, increments `racks.occupied`, resolves `studentUid`, generates a globally-unique OTP, stores its hash, increments `students.parcelsWaiting`, queues the STORED and PIN emails. |
| `resolvePin` | callable | Rate-limited per device. Hashes the submitted code, matches against **all** uncollected parcels, honours `pinAttempts.lockedUntil`. Returns the matched parcel summary or a generic failure. Never reveals how close a guess was. |
| `getFaceEmbedding` | callable | Returns one student's embedding for one requested UID. Logged. |
| `completeHandover` | callable | Marks the parcel collected, records `receiverUid`, `receiverIsOwner`, guard, timestamp, verification method and match score, decrements `racks.occupied` and `students.parcelsWaiting`, queues the COLLECTED email to the **owner**. |
| `enrolFace` | callable, admin only | Stores an embedding against a UID. Accepts the embedding, never a raw photo. |
| `sendEmail` | Firestore trigger on `emails/{id}` create | Reads the Resend key from config, sends, writes back `resendId` and `status`. Retries with backoff. |
| `importStudents` | callable, admin only | Parses CSV, upserts `students`. Reports rows added, updated, rejected. |
| `dashboardStats` | callable | Returns the aggregates for §5.17. Cache for 60s. |

**Gemini prompt contract for `scanLabel`:** the system instruction must require
raw JSON only — no prose, no markdown fences. Parse defensively and strip fences
anyway. On parse failure, return a failure result; never return partial garbage
the guard would have to notice and fix.

---

## 8. Emails

Three types, matching the Email Log filters. All sent via Resend from a Cloud
Function. Every email is written to the `emails` collection first, so the Email
Log is complete regardless of send outcome. **All three go to the owner.**

### STORED — sent when a parcel is recorded
Subject: `Your parcel has arrived - {deliveryService}`
Contains: owner name, delivery service, date of delivery, tracking number,
**storage rack**, **the guard who logged the parcel**, and the **date and
timestamp** it was logged. Collection instructions.

### PIN — sent immediately after STORED
Subject: `Collection code for your parcel`
Contains the 4-digit code and states plainly that it applies to **one specific
parcel**, identifying which. It must also say, in as many words: *anyone holding
this code can collect this parcel — only share it with someone you want to
collect on your behalf.* That sentence is the entire security model, in the one
place the owner will actually read it.

### COLLECTED — sent on handover, to the owner
Subject: `Parcel collected`
Contains: **who received it** (name and UID), whether that was the owner or
someone else, parcel details, **the guard who handed it over**, the **date and
timestamp**, and the verification method used. Where receiver != owner, say so in
the first line, not buried in a table. This email is how an owner discovers a
parcel was taken by someone they did not authorise.

---

## 9. Supporting logic

### 9.1 Rack assignment
20 racks (A1-A5, B1-B5, C1-C5, D1-D5), 10 slots each. Auto-assign the first rack
with a free slot in display order. Capacity enforced in a Firestore transaction.
The guard can always override to any rack with free space — the physical shelf is
the source of truth, not the database.

### 9.2 OTP generation and brute-force control
4 random digits. Store only the SHA-256 hash.

**The code must be unique across all uncollected parcels**, not just per student,
because it is entered with no student context. Regenerate on collision at write time.

**Consequence, stated plainly:** with a 4-digit code and, say, 20 parcels in
storage, roughly 1 in 500 random guesses hits a real parcel. A hundred guesses is
an 18% chance of opening something. This is only safe with hard rate limiting:

- 5 failed attempts -> that device locked for 10 minutes, event logged with the
  guard's ID
- Failures counted server-side in `pinAttempts`, never client-side
- Never indicate how close a guess was
- Alert the admin if any device trips the lockout twice in a day

If the uncollected count grows past ~100, move to 6 digits (`config/app.pinLength`
plus a 6-box screen). Recommend this to the owner as a cheap upgrade.

### 9.3 Name to UID matching (owner resolution)
`commitParcel` resolves `recipientNameRaw` to a student. Order:
1. Exact case-insensitive name match -> resolve
2. Single fuzzy match above threshold (Levenshtein <= 2, or normalised token
   overlap) -> resolve, flag `lowConfidenceMatch`
3. Multiple or no matches -> leave `studentUid` null

Unresolved parcels are still stored and still occupy a rack — they simply send no
email, and therefore have **no OTP anyone can present**. Surface them on the
Dashboard as **"Unmatched parcels"** with a way for the admin to assign an owner
manually, which then fires both emails. Without this the parcels are unreachable:
no owner, no code, no route out of the rack. This is the single most likely
real-world failure of the system.

### 9.4 Student CSV format
```csv
uid,name,email
U02180160,Aarav Sharma,aarav.sharma@plaksha.edu.in
```
UTF-8, header row required. Upsert on `uid`. Reject and report rows with a
malformed email or a duplicate UID. Never delete students absent from the file —
that would orphan live parcels.

### 9.5 Face database format — what to supply

A single **ZIP file**, structured:

```
faces.zip
  students.csv          <- same format as 9.4: uid,name,email
  photos/
    U02180160.jpg
    U02180161.jpg
    U02190045.png
    ...
```

Rules:
- **Filename = UID exactly**, including case. This is the join key; the CSV needs
  no photo column.
- One clearly visible face per image. Multiple faces -> rejected, reported.
- Front-facing, eyes open and visible, no sunglasses, no heavy shadow across the
  face. Glasses are fine. Masks are not.
- Minimum 400x400 px; 600x600 or larger preferred. ID-card crops are fine if the
  face region is at least 200x200.
- JPEG or PNG. Under 5MB each.
- A student missing a photo is not an error — they simply route to Manual
  Verification until enrolled.

**Import must run on the tablet**, via the Bulk Face Enrolment screen (§5.26),
not as a desktop script. Reason: a face embedding is only comparable to another
embedding produced by the *identical* model, weights and preprocessing. Generating
the seed set with a different ONNX build or a different alignment step produces
embeddings that silently fail to match every live scan — the app appears to work
and rejects everyone. Running the import through the same code path removes that
whole failure class.

If you would rather run it on a laptop, it is possible, but the script must load
the exact same model file the app ships and use identical 112x112 alignment. Test
by enrolling one person from the script and scanning them live before trusting it.

---

## 10. Face recognition

**On-device, no Python server.** Pipeline:

1. ML Kit detects the face and returns a bounding box.
2. Crop, align to 112x112, normalise.
3. Run an InsightFace recognition model (ArcFace / MobileFaceNet, ONNX) via
   `onnxruntime` in Flutter. Output: a 512-d embedding.
4. Cosine similarity against the selected receiver's stored embedding.
5. Above threshold -> match.

**Threshold:** start at 0.36 cosine distance, exposed in `config/app` so it can be
tuned without a rebuild. Measure false-accept and false-reject rates on real
students in week one. A false accept means a parcel handed to the wrong person, so
bias conservative — a false reject just routes to Manual Verification, which is a
working fallback.

**Model licensing — decide before go-live.** InsightFace's ONNX models are
MIT-licensed. InsightFace's own **InspireFace** SDK is stronger — under 5MB,
native Android, with built-in liveness/anti-spoofing — but requires a commercial
licence. Without liveness detection, a printed photo held to the camera will pass.
With a guard physically present this is a low risk, but it is a real one and the
owner should decide knowingly.

**Privacy.** Face embeddings are biometric data.
- Store the embedding; **delete the source photo after enrolment**. Do not keep
  the seed ZIP in Storage once processed.
- Get consent at enrolment, and offer an opt-out — a student who declines simply
  always uses Manual Verification. Never make face scan the only route to a parcel.
- Retain ID captures from manual verification for a fixed window (suggest 90 days)
  and auto-delete after.
- Log every `getFaceEmbedding` call. Biometric reads should be auditable.

---

## 11. Acceptance criteria

**Phase 1 — foundation**
- APK installs and runs on the target tablet
- CSV import loads students; malformed rows are reported, not silently dropped
- Guard ID login works; unknown ID is rejected with a visible error
- Home renders all six interactive elements with correct navigation

**Phase 2 — inbound**
- Scanning a real courier label populates the correct fields
- A failed scan lands on the blank form with the failure header, not a crash
- Every field is editable by tapping it
- STORE assigns a rack; the 11th parcel into a rack goes to the next rack
- DONE writes the parcel and sends STORED + PIN emails
- Two tablets storing simultaneously never occupy the same slot
- Generated codes are unique across all uncollected parcels

**Phase 3 — handover**
- A valid code entered cold resolves to exactly one parcel
- A wrong code increments the counter; 5 wrong codes lock the device for 10 minutes
- The receiver search defaults to the owner but allows any student to be chosen
- Face scan matches an enrolled receiver; an unenrolled one routes to Manual Verification
- Handover frees the rack slot and records `receiverUid` and `receiverIsOwner`
- The COLLECTED email goes to the **owner** and names the **receiver**
- A collection by a non-owner is visibly flagged on the handover screen and in the email

**Phase 4 — admin**
- Wrong admin credentials show a clear failure indication
- Guard change and delete both require the admin password
- Rack rename shows a confirmation; BACK on Shelves saves
- API key edit: SAVE commits, BACK discards, **OS back discards**
- Email Log filters by PIN / COLLECTED / STORED and expands an email in full
- Dashboard figures match a manual count in Firestore
- Bulk face enrolment processes the seed ZIP and reports per-UID failures
- A student enrolled from the seed ZIP is matched by a live scan on the tablet

**Phase 5 — polish**
- Loading animation appears on every wait over ~300ms and fills to a full cart at 100%
- OS back is disabled on exactly the screens listed in §4.2
- Airplane mode: the app degrades honestly and syncs on reconnect
- No API key is present anywhere in the built APK — verify by unzipping it
- The seed photo set is deleted from Storage after enrolment
