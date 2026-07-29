# Parcel App — Flow Diagrams

Transcribed from the hand-drawn UI Framework board. Five diagrams instead of one:
a single graph would be ~70 nodes and both humans and coding agents mis-read it.

Every colour link from the board has been resolved into an explicit navigation edge.
The original colour convention is preserved in the mapping table at the end.

**Revision 2** — handover reordered: the OTP is the first step, and the receiver
is captured separately from the owner.

---

## 0. Top-level map

```mermaid
flowchart TD
    START(["App launch"]) --> LOAD["Loading Screen"]
    LOAD --> AUTH[["1 - Auth and Session"]]
    AUTH --> HOME["Home Screen"]

    HOME -->|"green camera button"| IN[["2 - Inbound: log a parcel"]]
    HOME -->|"pink Enter Manually"| IN
    HOME -->|"cyan search card"| OUT[["3 - Handover: starts with the OTP"]]
    HOME -->|"grey asterisk, top-left"| SET["Settings"]
    HOME -->|"green person icon, top-right"| PROF["Profile / Log Out"]

    SET -->|"green - ADMIN LOGIN"| ADM[["4 - Admin"]]
    SET -->|"cyan - EMAIL LOG"| ELOG["Email Log"]
    SET -->|"pink - DASHBOARD"| DASH["Dashboard"]

    IN --> HOME
    OUT --> HOME
```

---

## 1. Auth and session

```mermaid
flowchart TD
    START(["App launch"]) --> LOAD["Loading Screen<br/>parcels fall into a shopping cart<br/>cart full at 100 percent"]
    LOAD --> GID["Guard ID Screen<br/>single input: GUARD ID"]

    GID -->|"ID matches an active guard"| OK["Logged In Screen<br/>NAME LOGGED IN"]
    GID -->|"ID not recognised"| GERR["Inline error<br/>guard not recognised"]
    GERR --> GID

    OK -->|"auto-advance, or tap"| HOME["Home Screen"]

    HOME -->|"green person icon"| PROF["Profile Screen<br/>NAME LOGGED IN<br/>LOG OUT button"]
    PROF -->|"back chevron"| HOME
    PROF -->|"LOG OUT"| GID
```

**Notes**
- Guard sign-in is Guard ID only, exactly as drawn. See `ASSUMPTION A4` in the spec for the recommended hardening.
- The session persists across app restarts until LOG OUT is pressed. A tablet reboot must not silently log a guard out mid-shift.

---

## 2. Inbound — logging a parcel in

```mermaid
flowchart TD
    HOME["Home Screen"] -->|"green camera button"| SCAN["Scan Label Screen<br/>camera viewport<br/>Processing indicator"]
    HOME -->|"pink Enter Manually"| BLANK["Parcel Details - BLANK<br/>all fields empty<br/>titles plus faded example entries"]

    SCAN -->|"YES - scan successful"| PRE["Parcel Details - PREFILLED<br/>fields from Gemini OCR<br/>tap any field to edit"]
    SCAN -->|"NOT SUCCESSFUL"| FAILHDR["Manual Scan Unsuccessful<br/>header banner"]
    FAILHDR --> BLANK2["Parcel Details - BLANK<br/>same screen, failure header"]

    PRE -->|"BACK"| HOME
    BLANK -->|"BACK"| HOME
    BLANK2 -->|"BACK"| HOME

    PRE -->|"STORE"| ASSIGN{"Auto-assign rack<br/>first rack with a free slot"}
    BLANK -->|"STORE"| ASSIGN
    BLANK2 -->|"STORE"| ASSIGN

    ASSIGN -->|"free slot found"| REC["Parcel Recorded<br/>PARCEL DETAILS block<br/>STORAGE RACK block"]
    ASSIGN -->|"all racks full"| FULLERR["Blocking dialog<br/>no free slots - call admin"]
    FULLERR --> PRE

    REC -->|"tap STORAGE RACK - manual override"| OVR["Rack Override Picker<br/>list of racks with free slots"]
    OVR -->|"select"| REC

    REC -->|"DONE"| FN[["Cloud Function commitParcel<br/>write parcel, occupy slot,<br/>generate OTP, queue 2 emails"]]
    FN --> EM1["Email: STORED<br/>to the parcel owner"]
    FN --> EM2["Email: PIN<br/>collection code for this parcel"]
    EM1 --> HOME
    EM2 --> HOME
```

**Notes**
- `Manual Scan Unsuccessful` is the same Parcel Details - BLANK screen with a failure header, not a separate screen.
- The rack is only committed on DONE, never on STORE. Pressing back from Parcel Recorded releases the tentative slot.

---

## 3. Handover

**The OTP comes first.** The student arrives and gives the guard the code from
their email. The code identifies exactly one parcel. Only then does the app ask
who is physically collecting it — and that person does **not** have to be the
owner. Anyone may collect; the app records who.

```mermaid
flowchart TD
    HOME["Home Screen"] -->|"cyan search card"| PIN["Enter PIN<br/>4-box Uber-style OTP<br/>student reads it out"]

    PIN -->|"no uncollected parcel<br/>has this code"| PERR["Inline error<br/>attempt counter"]
    PERR --> PIN
    PIN -->|"5 failed attempts"| LOCK["Device lockout 10 min<br/>return to Home<br/>log the event"]
    PIN -->|"back chevron"| HOME

    PIN -->|"code resolves to<br/>exactly one parcel"| PARCEL["PARCEL Screen<br/>DELIVERY SERVICE<br/>DATE OF DELIVERY<br/>NAME - the owner"]

    PARCEL -->|"BACK"| PIN
    PARCEL -->|"PROCEED"| SRCH["Receiver ID Search<br/>Enter Student ID of receiver<br/>empty state: Recent searches"]

    SRCH -->|"guard starts typing"| SUG["Receiver ID - Suggestions<br/>ranked by match on partial query,<br/>then number of parcels held"]
    SRCH -->|"back chevron"| PARCEL

    SUG -->|"select the receiver<br/>owner or anyone else"| FACE["Face Scan<br/>verifies the RECEIVER<br/>against the selected UID"]

    FACE -->|"YES - similarity above threshold"| DONE["Parcel Handed Over<br/>parcel details with receiver<br/>Email sent indicator"]
    FACE -->|"NOT SUCCESSFUL or<br/>receiver has no enrolled face"| MAN["Manual Verification<br/>capture STUDENT ID card<br/>of the receiver"]

    MAN -->|"RE-SHOT"| MAN
    MAN -->|"VERIFY - guard confirms visually"| DONE

    DONE --> FN2[["Cloud Function completeHandover<br/>mark collected, free the slot,<br/>record receiverUid + method"]]
    FN2 --> EM3["Email: COLLECTED<br/>sent to the OWNER<br/>naming the receiver, the guard,<br/>and the date and timestamp"]
    EM3 --> HOME
```

**Notes**
- The COLLECTED email goes to the **owner**, not the receiver. That is the whole
  accountability mechanism: if someone else collects your parcel, you find out.
- The face scan checks the **receiver** against the **receiver's own** enrolled
  face — it confirms "you are who you said you are", not "you are the owner".
- A receiver with no enrolled face routes straight to Manual Verification.

---

## 4. Settings and admin

```mermaid
flowchart TD
    HOME["Home Screen"] -->|"grey asterisk"| SET["Settings<br/>ADMIN LOGIN / EMAIL LOG / DASHBOARD"]
    SET -->|"back chevron"| HOME

    SET -->|"cyan - EMAIL LOG"| ELOG["Email Log<br/>a log of every email sent<br/>Filter chips: PIN / COLLECTED / STORED"]
    ELOG -->|"tap an email"| EEXP["Email expanded inline<br/>full detail"]
    EEXP -->|"tap again"| ELOG
    ELOG -->|"back chevron"| SET

    SET -->|"pink - DASHBOARD"| DASH["Dashboard<br/>same information as the<br/>AutoParcel dashboard"]
    DASH -->|"back chevron"| SET

    SET -->|"green - ADMIN LOGIN"| ALOG["Admin Login<br/>USERNAME<br/>PASSWORD"]
    ALOG -->|"credentials wrong"| AERR["Visible indication that<br/>credentials were incorrect"]
    AERR --> ALOG
    ALOG -->|"back chevron"| SET
    ALOG -->|"SUCCESSFUL LOGIN"| MENU["Admin Menu<br/>GUARDS / SHELVES / API KEYS"]
    MENU -->|"back chevron"| SET

    MENU -->|"pink - GUARDS"| GLIST["Guards List<br/>scrollable guard placards"]
    GLIST -->|"tap a placard"| GDET["Guard Detail<br/>GUARD NAME<br/>GUARD ID"]
    GLIST -->|"back chevron"| MENU
    GDET -->|"back chevron"| GLIST

    GDET -->|"CHANGE DETAILS - cyan"| GCHG["Confirm dialog<br/>asks for admin password"]
    GCHG -->|"cancel"| GDET
    GCHG -->|"password correct - update"| GLIST

    GDET -->|"DELETE GUARD - red"| GDEL["Confirm dialog<br/>asks for admin password"]
    GDEL -->|"cancel"| GDET
    GDEL -->|"password correct - delete"| GLIST

    MENU -->|"cyan - SHELVES"| SHV["Shelves<br/>animated scrollable rack view<br/>labels A1, C1, D2 ..."]
    SHV -->|"tap a rack name"| SREN["Rename confirm dialog"]
    SREN -->|"cancel"| SHV
    SREN -->|"confirm"| SHV
    SHV -->|"BACK - saves progress"| MENU

    MENU -->|"red - API KEYS"| KLIST["API Keys List<br/>each key masked<br/>EDIT control per key"]
    KLIST -->|"back chevron"| MENU
    KLIST -->|"EDIT"| KCONF["ARE YOU SURE YOU WANT TO<br/>CHANGE THE GEMINI API KEY?<br/>NO / YES"]
    KCONF -->|"NO - red"| KLIST
    KCONF -->|"YES - green"| KEDIT["API Key Edit<br/>masked input<br/>SAVE / BACK"]
    KEDIT -->|"SAVE - cyan"| KLIST
    KEDIT -->|"BACK - purple, discards"| KLIST

    MENU -.->|"one-off, hidden"| ENROL["Bulk Face Enrolment<br/>import ZIP, build embeddings<br/>on-device"]
    ENROL -.-> MENU
```

**Notes**
- **EMAIL LOG is a log of emails sent**, not an email login. Read-only history.
- The API Key Edit screen must **not** autosave. If the device or OS back button
  is pressed, the new key is discarded. This is written explicitly on the board.
- The Shelves screen is the opposite: its BACK **does** save progress.
- Bulk Face Enrolment is not on the board — it is the one-off import path for the
  seed face database. See spec §9.5.

---

## Colour to navigation mapping

The board's colour convention: a coloured element navigates along the arrow of the same colour.
Resolved here so the coding agent never has to interpret colour.

| Colour | Board meaning | Resolved destinations |
|---|---|---|
| Purple | Back / return navigation | Back chevron on every screen; API Key Edit BACK; Guards list return |
| Cyan / blue | Search, edit, save, positive-neutral | Home search card -> Enter PIN; Settings EMAIL LOG -> Email Log; Admin SHELVES -> Shelves; Guard CHANGE DETAILS -> confirm dialog; API Key SAVE; Parcel Recorded DONE |
| Green | Proceed / success / affirm | Home camera -> Scan Label; PARCEL PROCEED; STORE; Scan YES branch; Face Scan YES branch; Manual Verification VERIFY; Admin login SUCCESSFUL LOGIN; Settings ADMIN LOGIN; API key confirm YES |
| Red | Cancel / destructive / failure | BACK on Parcel and Parcel Details; Scan and Face Scan NOT SUCCESSFUL branches; Manual Verification RE-SHOT; DELETE GUARD; Admin API KEYS entry; API key confirm NO |
| Pink / magenta | Secondary entry points | Home Enter Manually -> Parcel Details BLANK; Settings DASHBOARD -> Dashboard; Admin GUARDS -> Guards List; API key EDIT control |
| Grey | Settings | Home asterisk -> Settings |
| Yellow | Annotations, not links | Requirements — all carried into the spec |
