# Argo Parcel App

The Argo Parcel App is a comprehensive tablet-based application built with Flutter and Firebase. It is designed to modernize and streamline the mailroom / parcel-handling process for educational institutions, allowing guards to effortlessly log, store, and distribute incoming packages to students.

## Key Features

### 📦 Parcel Management
- **Smart Logging:** Seamlessly scan labels and record incoming parcels.
- **Automated Routing:** Automatically match recipient names against the student database and assign optimal shelf space.
- **Secure Handovers:** PIN/OTP-based validation for handing over packages directly to students.

### 👤 Student & Guard Management
- **Live Facial Onboarding:** Admins can onboard new students instantly from the tablet interface. The app uses on-device ONNX models (MobileFaceNet) to capture and process 128-dimensional facial embeddings securely.
- **Guard Sessions:** Dedicated guard logins to monitor shift activities, with administrative access hidden behind a secondary PIN gate.

### 📧 Dynamic Notifications & Emails
- **Automated Reminders:** A robust Firebase Cloud Functions backend runs continuously, triggering email reminders for students who haven't picked up their waiting parcels.
- **Configurable Intervals:** Admins can dynamically change the reminder email frequency directly from the Admin Settings UI on the tablet—no code redeployment needed!
- **Custom Formatted Emails:** Emails are heavily styled to clearly display OTPs, exact arrival times, and friendly sign-offs.

### 📱 Tablet-First Design
- **Orientation Locked:** Custom `AndroidManifest.xml` and `Info.plist` settings lock the UI into a rigid portrait mode, ensuring the layout never breaks if the tablet is physically rotated.
- **Custom Branding:** Argo branding is injected deeply into the system via native app icons and a cohesive styling language (glassmorphism UI, vibrant gradients, and intuitive modals).

## Technology Stack
- **Frontend:** Flutter (Dart)
- **Backend Architecture:** Firebase Firestore, Firebase Authentication, Cloud Storage
- **Serverless Compute:** Firebase Cloud Functions (Node.js) for scheduled chron tasks and email triggers.
- **On-Device ML:** `onnxruntime` for real-time facial processing and embedding generation.
- **UI:** Custom theme utilizing modern standards (`AppColors`).

## Setup & Deployment
- The app should be built for Android/iOS tablets.
- Cloud Functions must be deployed via `firebase deploy --only functions`.
- For app icons, generate native files by running `dart run flutter_launcher_icons`.
