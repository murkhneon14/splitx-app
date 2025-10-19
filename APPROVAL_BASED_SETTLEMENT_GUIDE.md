# Approval-Based Settlement System - Complete Guide

## Overview
The settlement system now includes **UPI ID management** and **approval-based payment confirmation** for secure and verified transactions.

## New Features

### 1. UPI ID Management in Profile
Users can now set their UPI ID in the Profile screen, which is:
- ✅ Saved to **Firestore** (synced across devices)
- ✅ Cached in **SharedPreferences** (offline access)
- ✅ Automatically loaded when opening chat
- ✅ Used for receiving payments

### 2. Approval-Based Payment Confirmation
After a user confirms payment ("Yes, Paid"), the recipient must **approve** before settlement is recorded.

## Complete Flow

### Step 1: Set Up UPI ID (Both Users)

**Location:** Profile Screen → UPI ID Section

1. Open Profile screen
2. Tap on "Enter your UPI ID" card
3. Enter UPI ID (e.g., `9876543210@paytm` or `name@okaxis`)
4. Tap "Save"
5. UPI ID is saved to Firestore and synced

**Visual:**
```
┌─────────────────────────────────────┐
│ 💳 9876543210@paytm                 │
│    For receiving payments           │
│                                  ✏️ │
└─────────────────────────────────────┘
```

### Step 2: Direct Payment Flow (You Owe Money)

**User A (Payer):**
1. Opens chat with User B
2. Sees "You owe: ₹500"
3. Clicks "Settle up payment!"
4. Reviews payment dialog with User B's UPI ID
5. Clicks "Pay Now" → UPI app opens
6. Completes payment in UPI app
7. Returns to app
8. Clicks "Yes, Paid"
9. **Payment confirmation sent to User B**
10. Waits for approval...

**User B (Recipient):**
1. Receives **blue payment confirmation card** in chat
2. Sees: "Payment Confirmation Received - Amount: ₹500"
3. Verifies payment received in bank account
4. Clicks **"Approve"** button
5. Settlement is recorded automatically
6. Balance updates to ₹0

**Visual Flow:**
```
User A (Payer)                      User B (Recipient)
─────────────────────────────────────────────────────
Clicks "Settle up payment!"
UPI app opens
Completes payment
Clicks "Yes, Paid"
                                    
Confirmation sent ──────────►       Blue card appears
"Waiting for approval..."           "Payment Confirmation Received"
                                    "Please verify..."
                                    
                                    Checks bank account
                                    Clicks "Approve"
                                    
Settlement recorded ◄───────        Settlement recorded
Balance = ₹0                        Balance = ₹0
"All settled up! ✓"                 "All settled up! ✓"
```

### Step 3: Settlement Request Flow (They Owe You)

**User A (Requester):**
1. Opens chat with User B
2. Sees "They owe you: ₹500"
3. Clicks "Request Settlement"
4. Confirms sending request
5. **Orange settlement request** sent to User B

**User B (Payer):**
1. Receives **orange settlement request card**
2. Sees "Settlement Request Received - Amount: ₹500"
3. Clicks "Pay Now" → UPI app opens
4. Completes payment
5. Returns to app
6. Clicks "Yes, Paid"
7. **Payment confirmation sent to User A**

**User A (Requester/Recipient):**
1. Receives **blue payment confirmation card**
2. Verifies payment in bank account
3. Clicks **"Approve"**
4. Settlement recorded

## Message Types

### 1. Settlement Request (Orange)
```
┌─────────────────────────────────────┐
│ 💳 Settlement Request Received      │
│ Amount: ₹500.00                     │
│                                     │
│ [✓ Pay Now]  [✗ Decline]           │
└─────────────────────────────────────┘
```

### 2. Payment Confirmation (Blue - Pending)
```
┌─────────────────────────────────────┐
│ ⏳ Payment Confirmation Received    │
│ Amount: ₹500.00                     │
│                                     │
│ Please verify that you received     │
│ the payment before approving.       │
│                                     │
│ [✓ Approve]  [✗ Reject]            │
└─────────────────────────────────────┘
```

### 3. Payment Confirmation (Green - Approved)
```
┌─────────────────────────────────────┐
│ ✓ Payment Confirmation Received     │
│ Amount: ₹500.00                     │
│                                     │
│ ✓ Payment approved and settled      │
└─────────────────────────────────────┘
```

### 4. Payment Confirmation (Red - Rejected)
```
┌─────────────────────────────────────┐
│ ✗ Payment Confirmation Received     │
│ Amount: ₹500.00                     │
│                                     │
│ ✗ Payment rejected                  │
└─────────────────────────────────────┘
```

### 5. Settlement Completed (Green)
```
┌─────────────────────────────────────┐
│ ✓ You settled up                    │
│ Amount: ₹500.00                     │
│ Oct 19, 2025 3:39 PM               │
└─────────────────────────────────────┘
```

## Complete Example Scenario

### Scenario: Dinner Bill Split

**Setup:**
- Rahul and Priya went for dinner
- Rahul paid ₹1000
- They split equally: ₹500 each
- Priya owes Rahul ₹500

**Step-by-Step:**

1. **Rahul adds expense:**
   - Opens SplitX
   - Creates expense: "Dinner at Restaurant"
   - Amount: ₹1000
   - Splits with Priya
   - Expense notification sent to Priya

2. **Priya receives expense:**
   - Sees expense message in chat
   - "Rahul paid ₹1000 for Dinner"
   - "Your share is ₹500"

3. **Priya initiates payment:**
   - Opens chat with Rahul
   - Sees "You owe: ₹500"
   - Clicks "Settle up payment!"
   - Sees Rahul's UPI ID: `rahul@paytm`
   - Clicks "Pay Now"
   - UPI app opens with pre-filled details
   - Completes payment
   - Returns to app
   - Clicks "Yes, Paid"
   - Message: "Payment confirmation sent! Waiting for approval..."

4. **Rahul receives confirmation:**
   - Sees blue payment confirmation card
   - "Payment Confirmation Received - ₹500"
   - Checks bank account
   - Sees ₹500 credited
   - Clicks "Approve"
   - Message: "Payment approved and settlement recorded!"

5. **Both users see:**
   - Balance: ₹0
   - Button: "All settled up! ✓"
   - Green settlement message in chat

## Database Structure

### User Document (Firestore)
```javascript
{
  uid: "user_uid",
  username: "Rahul",
  email: "rahul@example.com",
  upiId: "rahul@paytm",  // NEW: UPI ID field
  upiIdUpdatedAt: Timestamp
}
```

### Payment Confirmation Message
```javascript
{
  text: "Payment confirmation: ₹500.00",
  senderId: "payer_uid",
  senderName: "Priya",
  timestamp: Timestamp,
  type: "payment_confirmation",
  amount: 500,
  isPaymentConfirmation: true,
  status: "pending",  // or "approved" or "rejected"
  payerId: "payer_uid",
  recipientId: "recipient_uid"
}
```

## Benefits of Approval-Based System

### Security
- ✅ **Prevents fraud**: Recipient must verify payment received
- ✅ **Double confirmation**: Both parties confirm transaction
- ✅ **Audit trail**: All confirmations recorded in chat

### Trust
- ✅ **Transparent**: Both users see confirmation status
- ✅ **Verifiable**: Recipient checks bank before approving
- ✅ **Reversible**: Can reject if payment not received

### Accuracy
- ✅ **No premature settlement**: Only settles after approval
- ✅ **Dispute prevention**: Clear confirmation process
- ✅ **Record keeping**: All steps documented in chat

## User Actions

### For Payer
1. **Pay directly** (if you owe)
2. **Confirm payment** after UPI transaction
3. **Wait for approval** from recipient

### For Recipient
1. **Request settlement** (if they owe)
2. **Verify payment** in bank account
3. **Approve or reject** payment confirmation

## Rejection Scenarios

### If Recipient Rejects Payment Confirmation

**Reasons to reject:**
- Payment not received in bank
- Wrong amount received
- Payment failed but payer confirmed
- Duplicate payment confirmation

**What happens:**
- Confirmation marked as "rejected"
- Balance remains unchanged
- Payer can try again
- Both users notified

**Next steps:**
- Payer checks payment status
- Retries payment if failed
- Contacts recipient to resolve
- Sends new confirmation after successful payment

## Tips for Users

### Setting UPI ID
1. **Use correct format**: `number@bank` or `name@bank`
2. **Verify before saving**: Double-check for typos
3. **Update if changed**: Keep it current
4. **Test first**: Send small test payment to verify

### Making Payments
1. **Check UPI ID**: Verify recipient's UPI ID before paying
2. **Confirm amount**: Match the amount shown
3. **Wait for success**: Ensure UPI transaction completes
4. **Only then confirm**: Click "Yes, Paid" only after success

### Approving Payments
1. **Check bank account**: Verify payment received
2. **Match amount**: Ensure correct amount credited
3. **Check sender**: Verify it's from the right person
4. **Then approve**: Only approve if everything matches

### If Issues Occur
1. **Payment failed**: Don't click "Yes, Paid"
2. **Wrong amount**: Reject and communicate
3. **Not received**: Reject and ask payer to check
4. **Duplicate**: Reject the duplicate confirmation

## Troubleshooting

### UPI ID not saving
- Check internet connection
- Ensure logged in with Firebase
- Try again after a few seconds

### Payment confirmation not appearing
- Refresh chat by closing and reopening
- Check internet connection
- Ensure both users are online

### Approval not working
- Check internet connection
- Ensure payment actually received
- Try closing and reopening chat

### Balance not updating after approval
- Close and reopen chat
- Check if settlement message appeared
- Verify expenses are properly synced

## Technical Implementation

### UPI ID Sync
1. User enters UPI ID in Profile
2. Saved to Firestore: `users/{uid}/upiId`
3. Cached in SharedPreferences
4. Loaded when opening chat
5. Used in UPI payment URL

### Approval Flow
1. Payer confirms payment
2. Payment confirmation message created
3. Recipient receives notification
4. Recipient verifies in bank
5. Recipient approves/rejects
6. If approved: Settlement recorded
7. If rejected: Status updated, no settlement

### Settlement Recording
Only happens after approval:
1. Update all unsettled expenses
2. Mark as settled in Firestore
3. Create settlement message
4. Update balances to zero
5. Show success notification

## Future Enhancements

- [ ] Automatic payment verification via UPI APIs
- [ ] Payment receipt upload
- [ ] Dispute resolution system
- [ ] Payment reminders
- [ ] Partial payment support
- [ ] Multiple payment methods
- [ ] Payment history export
- [ ] Analytics and insights
