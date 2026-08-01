# Argo Parcel App - Technical Stack Overview

This document outlines the complete technical architecture, libraries, and integrations that power the Argo Parcel Management System.

## 1. Frontend Architecture (Mobile App)
The client application is a cross-platform mobile app built primarily for tablets used by guards and administrators.

* **Framework:** Flutter (Dart `^3.12.2`)
* **Core Integrations:**
  * **Firebase Core & Auth:** Manages secure connections and authentication (`firebase_auth`).
  * **Cloud Firestore:** Real-time NoSQL database client (`cloud_firestore`).
  * **Cloud Functions:** Client SDK to trigger serverless backend operations (`cloud_functions`).
  * **Firebase Storage:** Uploading and retrieving media (`firebase_storage`).
* **UI & Data Visualization:**
  * **Lottie (`lottie`):** Renders high-quality JSON-based vector animations (e.g., loading screens, processing animations).
  * **FL Chart (`fl_chart`):** Renders interactive analytics charts on the admin dashboard.
  * **Cupertino Icons:** For platform-native styling.
* **Device & Hardware APIs:**
  * **Camera (`camera`):** Interfaces with device cameras to scan shipping labels and capture student faces.
  * **Image Picker / File Picker:** Select images from the gallery and import CSV/ZIP files for bulk enrollment.
  * **Local Storage:** `shared_preferences` for managing persistent local device state (e.g., locking out devices after failed PIN attempts).

## 2. Backend Architecture (Serverless)
The backend operates entirely on Google Cloud's serverless infrastructure.

* **Runtime:** Node.js 20 via Firebase Cloud Functions.
* **Key Packages & Libraries:**
  * **Firebase Admin SDK (`firebase-admin`):** Full-access backend client for Firestore and Firebase Auth (used for setting Custom Claims and generating embeddings).
  * **Nodemailer (`nodemailer`):** Used in background CRON jobs to dispatch email notifications.
  * **CSV Parser (`csv-parse`):** Parses bulk student enrollment datasets.
  * **Jimp (`jimp`):** Image processing library for resizing and normalizing faces before embedding generation.
* **AI & Machine Learning (Backend):**
  * **ONNX Runtime (`onnxruntime-node`):** Executes the `mobilefacenet.onnx` model on the server to generate vector embeddings for newly onboarded students.
  * **Google Gen AI / Vertex AI (`@google/genai`):** Uses the **Gemini 2.5 Flash** vision model to parse uploaded images of shipping labels and strictly extract JSON data (`deliveryService`, `recipientName`, `trackingNumber`).

## 3. Database & Storage Layer
Data is structured across Firebase services to enable real-time updates and secure access.

* **Cloud Firestore (Collections):**
  * `students`: Stores student profiles, contact info, and their mathematical face embeddings (for facial recognition).
  * `parcels`: Tracks the lifecycle of every package (status: `stored`, `collected`), tracking numbers, assigned racks, and timestamps.
  * `racks`: Manages physical capacity and real-time occupancy counts (e.g., `rack_A1` ... `rack_D5`).
  * `guards`: Maintains a directory of active/inactive security personnel.
  * `emails`: A queue collection for dispatching notifications.
  * `pinAttempts`: Tracks rate-limiting and device lockouts for PIN entry brute-force protection.
* **Firebase Storage:**
  * `faces/`: A secure bucket storing the raw JPG/PNG crops of student faces.

## 4. Key Workflows & Integrations

### Parcel Intake & AI Label Scanning
When a guard receives a package, they snap a photo of the shipping label. The Flutter app converts this to base64 and triggers the `scanLabel` cloud function. The backend invokes **Vertex AI (Gemini)** to read the text in the image and extract structured JSON data. 

### Automated Rack Assignment
The `assignRack` cloud function dynamically queries the `parcels` collection to evaluate the occupancy of all shelves. It algorithmically selects the first shelf with less than 5 stored parcels and returns the location to the frontend. Simultaneously, a Firestore Trigger (`syncRackOccupancy`) automatically increments/decrements the counters on the `racks` collection in the background whenever a parcel is added or collected.

### Facial Recognition Handover
During pickup, the app uses Google ML Kit (`google_mlkit_face_detection`) to locate a face in the camera frame. The cropped face is passed through the local `mobilefacenet.onnx` model to generate a live vector embedding. The app then fetches the stored embedding from Firestore for the target student and computes the mathematical distance (Cosine Similarity). If it passes the threshold, the parcel is released.

### Automated Notifications & Reminders
A Cloud Scheduler CRON job (`checkAndSendReminders`) runs every 2 minutes. It queries all `stored` parcels and compares their arrival timestamp against the current time. If a parcel has been waiting too long, the backend queues an email into the `emails` collection and dispatches a reminder (with the collection OTP and Gate instructions) via `nodemailer`.
