# Argo Parcel App - Technical Stack Overview

This document provides a highly detailed, exhaustive overview of the complete technical architecture, libraries, and integrations that power the Argo Parcel Management System.

## 1. Frontend Architecture (Tablet Application)
The client application is a cross-platform mobile app built strictly for tablets used by guards and administrators.

* **Framework:** Flutter (Dart `^3.12.2`)
* **Core Firebase Integrations:**
  * **`firebase_core` / `firebase_app_check`:** Bootstraps the app and secures API access.
  * **`firebase_auth`:** Manages secure guard and admin login sessions.
  * **`cloud_firestore`:** Real-time NoSQL database client.
  * **`cloud_functions`:** Triggers serverless backend endpoints.
  * **`firebase_storage`:** Uploads and retrieves media (like student faces).
* **Hardware & System APIs:**
  * **`camera`:** Interfaces with tablet cameras to scan shipping labels and capture live student faces.
  * **`image_picker` / `file_picker`:** Allows users to select files (CSV/ZIP) or images from local storage.
  * **`permission_handler`:** Requests and manages runtime permissions (camera, storage).
  * **`path_provider`:** Accesses native file system paths (e.g., temporary directories for model execution).
  * **`shared_preferences`:** Manages persistent local device state (e.g., locking out devices after failed PIN attempts).
* **UI & Data Visualization:**
  * **`lottie`:** Renders high-quality JSON-based vector animations for loaders and states.
  * **`fl_chart`:** Renders interactive data visualization analytics on the admin dashboard.
  * **`cupertino_icons`:** Provides platform-native styling components.
  * **`flutter_launcher_icons`:** Generates and injects the native Argo branding into Android `mipmap` files.
* **Data Processing (Frontend):**
  * **`csv` / `excel`:** Parses bulk student enrollment datasets directly on the device.
  * **`archive`:** Extracts bulk `.zip` files containing bulk face images.
  * **`intl`:** Handles internationalization and complex date formatting.

## 2. Artificial Intelligence & Computer Vision Layer
The system employs a sophisticated hybrid AI architecture (running both on-device and on the cloud).

* **Facial Detection & Recognition (InsightFace Architecture):**
  * **`google_mlkit_face_detection` (Frontend):** High-speed ML Kit model to locate and extract facial bounding boxes from a live camera feed.
  * **`image` (Frontend):** Performs memory-efficient cropping and preprocessing of the detected face.
  * **`onnxruntime` (Frontend):** Executes the `mobilefacenet.onnx` model locally on the tablet.
  * **InsightFace / MobileFaceNet Integration:** The underlying ONNX model uses the **InsightFace** architecture (specifically MobileFaceNet trained with ArcFace loss) to map a normalized face crop into a highly accurate 128-dimensional vector embedding.
* **Generative AI (Backend):**
  * **`@google/genai`:** Interacts with Google's Vertex AI/Gemini 2.5 Flash model. It processes images of incoming parcels, performing OCR and semantic parsing to extract JSON payloads (Carrier, Recipient, Tracking Number).

## 3. Backend Architecture (Serverless Cloud Functions)
The backend operates entirely on Google Cloud's serverless infrastructure (Node.js 20).

* **Core SDKs:**
  * **`firebase-functions` / `firebase-admin`:** Provides full administrative access to Firestore and Auth (used for setting Custom Claims, bypassing security rules, and processing triggers).
* **Communication Protocols (SMTP):**
  * **`nodemailer` (SMTP Client):** Connects to a standard **SMTP (Simple Mail Transfer Protocol)** server to dispatch highly formatted HTML email notifications (OTPs, Gate instructions, Reminders) to students.
* **Data Processing (Backend):**
  * **`csv-parse`:** Stream-processes bulk CSV data uploaded to the backend.
  * **`jimp`:** A robust image processing library used on the backend to resize, crop, and normalize images before they are passed into embedding models.
  * **`onnxruntime-node`:** The backend equivalent of the ONNX runtime. It allows the server to run the InsightFace/MobileFaceNet model independently (e.g., when enrolling students via bulk scripts).
* **Dev Dependencies:**
  * **`typescript` / `@types/node` / `@types/nodemailer`:** Used for strong typing and compiling backend scripts.

## 4. Database & Storage Layer (Firestore & Storage)
Data is structured across Firebase services to enable real-time updates and secure access.

* **Cloud Firestore (Collections):**
  * `students`: Stores student profiles, contact info, and their InsightFace vector embeddings.
  * `parcels`: Tracks the lifecycle of every package (status: `stored`, `collected`), tracking numbers, assigned racks, and timestamps.
  * `racks`: Manages physical capacity and real-time occupancy counts (e.g., `rack_A1` ... `rack_D5`).
  * `guards`: Maintains a directory of active/inactive security personnel.
  * `emails`: A queue collection. The backend listens to this to dispatch SMTP emails.
  * `pinAttempts`: Tracks rate-limiting and device lockouts for PIN entry brute-force protection.
  * `settings`: Stores global app configurations (e.g., `reminderIntervalMinutes`).
* **Firebase Storage:**
  * `faces/`: A secure bucket storing the raw JPG/PNG crops of student faces for audit purposes.

## 5. Key System Workflows

### Parcel Intake & AI Label Scanning
When a guard receives a package, they snap a photo of the shipping label. The Flutter app converts this to base64 and triggers the `scanLabel` cloud function. The backend invokes **Vertex AI (Gemini)** to read the text in the image and extract structured JSON data. 

### Automated Rack Assignment
The `assignRack` cloud function dynamically queries the `parcels` collection to evaluate the occupancy of all shelves. It algorithmically selects the first shelf with less than 5 stored parcels and returns the location to the frontend. Simultaneously, a Firestore Trigger (`syncRackOccupancy`) automatically increments/decrements the counters on the `racks` collection in the background whenever a parcel is added or collected.

### InsightFace Facial Recognition Handover
During pickup, the app uses ML Kit to locate a face in the camera frame. The cropped face is passed through the local `mobilefacenet.onnx` (InsightFace) model to generate a live vector embedding. The app then fetches the stored embedding from Firestore for the target student and computes the mathematical distance (Cosine Similarity). If it passes the threshold, the parcel is released.

### Automated SMTP Notifications & Reminders
A Cloud Scheduler CRON job (`checkAndSendReminders`) runs dynamically based on the Admin settings. It queries all `stored` parcels and compares their arrival timestamp against the current time. If a parcel has been waiting too long, the backend queues an email into the `emails` collection and dispatches an SMTP reminder via `nodemailer`.
