# Firebase Cloud Functions for SplitX

This directory contains the Firebase Cloud Functions for the SplitX application, which handle push notifications for chat messages.

## Prerequisites

1. Install Node.js (v16 or later)
2. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```
3. Log in to Firebase:
   ```bash
   firebase login
   ```
4. Install dependencies:
   ```bash
   cd functions
   npm install
   ```

## Available Functions

1. **sendPushNotification**
   - Triggered when a new document is added to the `notifications` collection
   - Sends a push notification to the specified device token
   - Updates the notification document with the send status

2. **onMessageCreated**
   - Triggered when a new message is added to a chat
   - Creates a notification document for the recipient
   - The notification document triggers the `sendPushNotification` function

## Deployment

To deploy the functions to Firebase, run:

```bash
cd functions
npm run deploy
```

This will compile the TypeScript code and deploy the functions to your Firebase project.

## Local Development

To run the functions locally with the Firebase Emulator:

```bash
cd functions
npm run serve
```

This will start the Firebase Emulator and allow you to test the functions locally.

## Testing

1. Send a test message in the app
2. Check the Firebase Console > Functions > Logs for any errors
3. Check the `notifications` collection in Firestore to see the notification documents

## Troubleshooting

- If you get permission errors, make sure you're logged in with the correct Firebase account:
  ```bash
  firebase login:list  # Check current login status
  firebase logout     # Log out if needed
  firebase login      # Log in again
  ```

- If you get dependency errors, try:
  ```bash
  cd functions
  rm -rf node_modules
  npm install
  ```
