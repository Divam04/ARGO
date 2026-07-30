# Live-Updatable Device-Frame Image Showcase

This project is a React-based web application that displays a live-updatable device frame showcase, integrated with Firebase for data management and storage.

## Development

1. **Install Dependencies**
   ```bash
   npm install
   ```

2. **Run Locally**
   ```bash
   npm run dev
   ```
   *Note: If no Firebase credentials are provided in `.env`, the app automatically runs in Mock Mode so you can see the UI and interact with it.*

## Firebase Setup

1. **Create Firebase Project**
   - Go to the [Firebase Console](https://console.firebase.google.com/) and create a new project.
   - Enable **Authentication** (Email/Password).
   - Enable **Firestore Database** (start in production mode).
   - Enable **Storage** (start in production mode).

2. **Configure Environment**
   - Create a web app in the Firebase project settings to get your config keys.
   - Copy `.env.example` to `.env` and paste your keys into the variables.
   - `VITE_FIREBASE_API_KEY=...`

3. **Create Admin User**
   - Go to Authentication -> Users in the Firebase console.
   - Add a user manually (this will be the one and only admin account).

4. **Update Firebase Config**
   - Open `.firebaserc` and change `your-firebase-project-id` to your actual project ID.

## Deployment

To deploy to Firebase Hosting, you must have the Firebase CLI installed:

```bash
npm install -g firebase-tools
firebase login
```

Once logged in and configured, deploy using:

```bash
npm run build
firebase deploy
```

This command will deploy your built React app, as well as update the Firestore and Storage security rules securely.

## Admin Access
The management UI is completely hidden from the public viewer and does not leak any code to the client on the main path.
Admin URL: `/manage-7f3kx9q2` (Remember to change this slug in `src/App.tsx` prior to deploying for added obscurity).
