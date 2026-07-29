# Agent Build Plan

How to hand this to a coding agent so it produces a working APK instead of a
plausible-looking half-app.

---

## Setup

1. **One repo, one agent.** Do not split frontend and backend across different
   models. This codebase is small enough that contract drift between agents costs
   more than any quality gain.
2. **Pick the agent you already pay for.** Claude Code and Codex will both build
   this. If you have neither: this work is repo-reasoning-shaped (many files
   sharing one data model), which is the lane Claude Code is reported stronger in.
   Codex on GPT-5.6 Sol is a fine alternative and stronger on long terminal chains.
3. **Install Firebase Agent Skills for Flutter** before the first prompt. It
   works with both Claude Code and Codex and removes the most common class of
   Firebase hallucination.
4. **Put both spec files in the repo root** as `PARCEL_APP_SPEC.md` and
   `PARCEL_APP_FLOWS.md`, and commit them before writing any code.
5. **Optional review pass.** After each phase, have a *different* lab's model
   review the diff. Kimi K3 is cheap and works well for this. Cross-lab review
   catches more than same-model review.

---

## The standing instruction

Paste this at the start of every session:

> You are building a Flutter tablet app from a written specification. Read
> `PARCEL_APP_SPEC.md` and `PARCEL_APP_FLOWS.md` in full before writing any code,
> and re-read the relevant section before each task.
>
> Rules:
> - The Firestore schema in §6 is fixed. Do not invent field names. If something
>   is missing, propose a schema change and wait.
> - No API keys in the client. Vertex AI and Resend are called only from Cloud
>   Functions. If you find yourself putting a key in Dart, stop.
> - The assumptions in §1 (A1–A6) are decisions, not suggestions. If you think one
>   is wrong, say so — do not quietly implement the alternative.
> - Build one phase at a time. At the end of each phase, run `flutter build apk`
>   and make it pass before moving on.
> - When the spec and your instinct disagree, the spec wins. Ask.

---

## Phase 1 — Foundation

**Goal:** APK installs, guard logs in, home screen navigates.

Build: Flutter project targeting the tablet's Android version, Firebase wiring
(Firestore, Auth, Storage, Functions, App Check), the full Firestore schema from
§6 with security rules, `importStudents` and a CSV import path, seed the 20 racks,
Guard ID login (§5.2–5.4), Home (§5.5) with all six elements navigating to
placeholder screens, the loading animation (§4.1), and the back-button rule (§4.2)
as a reusable wrapper.

**Done when:** the APK sideloads and runs on the actual tablet, a CSV of real
students imports with a rejection report, an unknown Guard ID is refused visibly,
and every Home element routes somewhere.

---

## Phase 2 — Inbound

**Goal:** a real courier label becomes a stored parcel and two emails.

Build: `scanLabel` (§7) with the strict-JSON Gemini contract, Scan Label (§5.6),
Parcel Details in all three states (§5.7), `assignRack` and `commitParcel` with
transactional capacity enforcement (§7, §9.1), Parcel Recorded with the rack
override picker (§5.8), PIN generation and hashing (§9.2), name→UID matching
(§9.3), the `sendEmail` trigger, and the STORED and PIN templates (§8).

**Done when:** scanning a real label fills the fields correctly; a deliberately
bad scan lands on the blank form with the failure header; the 11th parcel into a
rack rolls to the next rack; two tablets storing at once never collide on a slot;
both emails arrive.

---

## Phase 3 — Handover

**Goal:** a student collects a parcel end to end.

Build in this order: Enter PIN as the **entry point** with `resolvePin` and
server-side device lockout (§5.9, §9.2), PARCEL (§5.10), Receiver ID Search with
the owner shortcut and two-factor ranking (§5.11), on-device face recognition
(§10), Face Scan against the *receiver* (§5.12), Manual Verification (§5.14),
Parcel Handed Over showing owner vs receiver (§5.13), `completeHandover` and the
COLLECTED email to the owner (§7, §8).

The owner/receiver split is the thing to hold onto here. `studentUid` is who owns
the parcel; `receiverUid` is who took it; they are frequently different and that
is normal. An agent will try to collapse them.

Do the ONNX/ML Kit integration **first** in this phase — it is the only genuinely
unfamiliar piece and the one most likely to need a different approach than the
agent's first guess. Get an embedding out of a real photo on the real tablet
before building any of the screens around it.

**Done when:** a valid code entered cold resolves to one parcel; five wrong codes
lock the device; a non-owner can be selected as receiver and the handover screen
flags it; the rack slot frees; the COLLECTED email reaches the **owner** and names
the **receiver**, the guard and the timestamp.

---

## Phase 4 — Admin

**Goal:** the system is maintainable without a developer.

Build: Bulk Face Enrolment first (§5.26, §9.5) — the seed face database has to
load before anything else in this phase is testable. Then Settings (§5.15), Admin Login with visible credential feedback (§5.18),
Admin Menu (§5.19), Guards list and detail with password-confirmed change and
soft delete (§5.20–5.21), Shelves with the animated scrollable rack view and
save-on-back (§5.22), API Keys list, confirmation and edit with **no autosave**
(§5.23–5.25), Email Log with filters and inline expansion (§5.16), Dashboard at
AutoParcel parity including Excel export (§5.17, §3 of the source screenshot).

**Done when:** the API key edit screen discards on OS back — test this explicitly,
it is the one behaviour written in capitals on the board.

---

## Phase 5 — Polish and hardening

Loading animation everywhere; back-button audit against §4.2; offline queue and
sync (§4.4); clock-skew warning (§4.3); face threshold tuning on real students
(§10); unmatched-parcel surface on the dashboard (§9.3); unzip the release APK
and confirm no key is present.

---

## What to watch for

The three things most likely to go wrong, in order:

1. **The agent puts an API key in the Flutter app** because it is the shortest
   path to a working demo. Check the diff every phase.
2. **Face recognition gets stubbed** with a placeholder that always returns true,
   and stays stubbed. Test it against a real face before Phase 3 closes.
2b. **Seed embeddings generated by a different pipeline than the live one.** The
   app then rejects everybody while looking like it works. Run the import through
   the same on-device code path (§9.5).
3. **Rack capacity gets enforced only in the UI.** Two tablets, one rack, same
   slot. Force this in a transaction and test it with two devices.
4. **`receiverUid` quietly defaults to `studentUid`.** The audit trail then says
   every parcel was collected by its owner, which is exactly the fact the system
   exists to record. Test with a deliberate non-owner collection.

And the one to watch for in yourself: an APK that demos well on the bench is not
the same as one that survives a Monday. Per the daily intake chart on AutoParcel,
Mondays run roughly double every other day — test with a queue of students, not
one at a time.
