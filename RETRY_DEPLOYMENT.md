# ⏳ Waiting for Permissions to Propagate

## ✅ Good News!

Your billing is enabled and the deployment is progressing! The error is just a **temporary permissions issue**.

## 🔄 What's Happening

Firebase is setting up Eventarc Service Agent permissions for the first time. This takes **2-5 minutes**.

## ⏰ Wait 2-3 Minutes, Then Retry

**Step 1: Wait** (grab a coffee ☕)

**Step 2: Retry deployment:**
```bash
cd c:\splitX
firebase deploy --only functions
```

## 🎯 If It Still Fails

### Option 1: Grant Permissions Manually

1. Go to: https://console.cloud.google.com/iam-admin/iam?project=splitx-20445
2. Find the service account: `service-PROJECT_NUMBER@gcp-sa-eventarc.iam.gserviceaccount.com`
3. Click "Edit" (pencil icon)
4. Add role: **Eventarc Service Agent**
5. Save and retry deployment

### Option 2: Use 1st Gen Functions (Simpler)

If you want to avoid this complexity, use 1st gen functions:

**Edit `functions/src/index.ts`:**
```typescript
import * as functions from 'firebase-functions/v1';

// Change from:
export const sendPushNotification = functions.firestore.onDocumentCreated(...)

// To:
export const sendPushNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snapshot, context) => {
    // ... rest of code
  });
```

**Edit `functions/package.json`:**
```json
"engines": {
  "node": "18"  // Use 18 instead of 20 for 1st gen
}
```

Then rebuild and deploy:
```bash
cd c:\splitX\functions
npm run build
cd ..
firebase deploy --only functions
```

## 📊 Current Status

- ✅ Billing enabled
- ✅ APIs enabled
- ✅ Code uploaded
- ⏳ Waiting for Eventarc permissions (2-5 minutes)
- ⏳ Ready to retry deployment

## 🚀 After Successful Deployment

You'll see:
```
✔  functions[sendPushNotification(us-central1)] Successful create operation.
✔  functions[onMessageCreated(us-central1)] Successful create operation.

✔  Deploy complete!
```

Then test your notifications! 🎉
