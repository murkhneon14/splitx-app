# 🚀 Deploy Cloud Functions - Step by Step

## ❌ Current Error

```
Error: Request to https://cloudresourcemanager.googleapis.com/v1/projects/splitx-app 
had HTTP Error: 403, The caller does not have permission
```

## ✅ Fix Steps

### Step 1: Enable Required APIs

Go to Google Cloud Console and enable these APIs:

1. **Cloud Functions API**
   - https://console.cloud.google.com/apis/library/cloudfunctions.googleapis.com?project=splitx-app

2. **Cloud Build API**
   - https://console.cloud.google.com/apis/library/cloudbuild.googleapis.com?project=splitx-app

3. **Cloud Resource Manager API**
   - https://console.cloud.google.com/apis/library/cloudresourcemanager.googleapis.com?project=splitx-app

4. **Artifact Registry API**
   - https://console.cloud.google.com/apis/library/artifactregistry.googleapis.com?project=splitx-app

### Step 2: Check IAM Permissions

1. Go to: https://console.cloud.google.com/iam-admin/iam?project=splitx-app
2. Find your email address
3. Ensure you have these roles:
   - ✅ **Owner** OR
   - ✅ **Editor** OR
   - ✅ **Cloud Functions Admin** + **Service Account User**

### Step 3: Re-authenticate Firebase CLI

```bash
firebase logout
firebase login
```

### Step 4: Set the Correct Project

```bash
cd c:\splitX
firebase use splitx-app
```

### Step 5: Deploy Functions

```bash
firebase deploy --only functions
```

## 🎯 Alternative: Deploy via Firebase Console

If CLI deployment keeps failing, you can deploy manually:

### Option A: Use Firebase Console

1. Go to: https://console.firebase.google.com/project/splitx-app/functions
2. Click "Get Started" if you haven't set up functions
3. Upload your functions code

### Option B: Use Google Cloud Console

1. Go to: https://console.cloud.google.com/functions/list?project=splitx-app
2. Click "Create Function"
3. For each function:

**Function 1: sendPushNotification**
- Name: `sendPushNotification`
- Trigger: Cloud Firestore
- Event: `document.create`
- Document path: `notifications/{notificationId}`
- Runtime: Node.js 16
- Entry point: `sendPushNotification`
- Source code: Copy from `c:\splitX\functions\src\index.ts`

**Function 2: onMessageCreated**
- Name: `onMessageCreated`
- Trigger: Cloud Firestore
- Event: `document.create`
- Document path: `chats/{chatId}/messages/{messageId}`
- Runtime: Node.js 16
- Entry point: `onMessageCreated`
- Source code: Copy from `c:\splitX\functions\src\index.ts`

## 🔧 Quick Commands

```bash
# Check if you're logged in
firebase login:list

# Check current project
firebase projects:list

# Check your permissions
firebase projects:list

# Force re-login
firebase login --reauth

# Deploy with debug output
firebase deploy --only functions --debug
```

## ✅ Success Indicators

After successful deployment, you'll see:

```
✔  functions[sendPushNotification(us-central1)] Successful create operation.
✔  functions[onMessageCreated(us-central1)] Successful create operation.

✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/splitx-app/overview
```

## 📱 Test After Deployment

1. Open your app
2. Send a message
3. Put app in background
4. You should receive a notification! 🎉

## 🐛 Still Not Working?

### Check Function Logs:
```bash
firebase functions:log
```

### Check Firestore:
1. Go to Firebase Console → Firestore
2. Look at `notifications` collection
3. Check if documents are being created
4. Check `status` field (should be 'sent')

### Manual Test:
1. Go to Firestore Console
2. Create a test document in `notifications` collection:
```json
{
  "to": "YOUR_FCM_TOKEN_HERE",
  "notification": {
    "title": "Test Notification",
    "body": "This is a test"
  },
  "data": {
    "type": "test"
  },
  "status": "pending"
}
```
3. Check if notification is received
4. Check if `status` changes to 'sent'
