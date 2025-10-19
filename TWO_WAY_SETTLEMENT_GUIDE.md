# Two-Way Settlement System - User Guide

## Overview
The settle up payment feature now works **both ways**! Either user can initiate settlement, and the system intelligently handles who owes whom.

## How It Works

### Scenario 1: You Owe Money (Balance is Negative)
**Button shows:** "Settle up payment!"

1. Click "Settle up payment!" button
2. Review payment dialog with amount and UPI details
3. Click "Pay Now" → UPI app opens
4. Complete payment in UPI app
5. Return to app and confirm payment
6. Settlement is recorded automatically

### Scenario 2: They Owe You Money (Balance is Positive)
**Button shows:** "Request Settlement"

1. Click "Request Settlement" button
2. Confirm sending settlement request
3. Request is sent as a message in chat
4. Wait for them to approve and pay
5. Once paid, balance updates automatically

### Scenario 3: Receiving a Settlement Request
When someone sends you a settlement request, you'll see an **orange card** in the chat with two buttons:

**Option 1: Pay Now** (Green button)
- Launches UPI app with pre-filled details
- Complete payment
- Confirm in app
- Settlement recorded automatically

**Option 2: Decline** (Red button)
- Rejects the settlement request
- Request marked as declined
- No payment made

## Visual States

### Settlement Request Message (Pending)
```
┌─────────────────────────────────────┐
│ 💳 Settlement Request Received      │
│ Amount: ₹500.00                     │
│                                     │
│ [✓ Pay Now]  [✗ Decline]           │
└─────────────────────────────────────┘
```

### Settlement Request Message (Approved)
```
┌─────────────────────────────────────┐
│ ✓ Settlement Request Received       │
│ Amount: ₹500.00                     │
│                                     │
│ ✓ Payment completed                 │
└─────────────────────────────────────┘
```

### Settlement Request Message (Rejected)
```
┌─────────────────────────────────────┐
│ ✗ Settlement Request Received       │
│ Amount: ₹500.00                     │
│                                     │
│ ✗ Request declined                  │
└─────────────────────────────────────┘
```

### Settlement Completed Message
```
┌─────────────────────────────────────┐
│ ✓ You settled up                    │
│ Amount: ₹500.00                     │
│ Oct 19, 2025 3:14 PM               │
└─────────────────────────────────────┘
```

## Button States

### Bottom Button States:
1. **"Settle up payment!"** (Enabled, Green)
   - You owe money
   - Click to pay directly

2. **"Request Settlement"** (Enabled, Green)
   - They owe you money
   - Click to send payment request

3. **"All settled up! ✓"** (Disabled, Grey)
   - Balance is zero
   - Nothing to settle

4. **Loading...** (Spinner)
   - Calculating balance
   - Please wait

## Complete Flow Examples

### Example 1: Direct Payment (You Owe ₹500)
```
User A (You)                    User B (Friend)
─────────────────────────────────────────────────
Opens chat
Sees "You owe: ₹500"
Clicks "Settle up payment!"
                                
Reviews payment dialog
Clicks "Pay Now"
                                
UPI app opens
Completes payment
                                
Returns to app
Confirms payment
                                
Settlement recorded  ────────►  Receives settlement message
Balance = ₹0                    Balance = ₹0
"All settled up! ✓"             "All settled up! ✓"
```

### Example 2: Settlement Request (They Owe ₹500)
```
User A (You)                    User B (Friend)
─────────────────────────────────────────────────
Opens chat
Sees "They owe you: ₹500"
Clicks "Request Settlement"
                                
Confirms request
Sends request        ────────►  Receives request message
                                Orange card appears
                                "Settlement Request Received"
                                
Waits...                        Reviews amount
                                Clicks "Pay Now"
                                
                                UPI app opens
                                Completes payment
                                
                                Returns to app
                                Confirms payment
                                
Receives notification ◄────────  Settlement recorded
Balance = ₹0                    Balance = ₹0
"All settled up! ✓"             "All settled up! ✓"
```

### Example 3: Declined Request
```
User A (You)                    User B (Friend)
─────────────────────────────────────────────────
Opens chat
Sees "They owe you: ₹500"
Clicks "Request Settlement"
                                
Sends request        ────────►  Receives request message
                                Reviews amount
                                Clicks "Decline"
                                
Request declined     ◄────────  Request marked as declined
Balance still ₹500              Balance still -₹500
Can send new request            Can pay later
```

## Key Features

### ✅ Smart Button Logic
- Automatically detects who owes whom
- Shows appropriate action (Pay or Request)
- Disables when settled

### ✅ Interactive Messages
- Settlement requests appear as actionable cards
- Pay Now and Decline buttons in chat
- Real-time status updates

### ✅ Visual Feedback
- Orange for pending requests
- Green for approved/completed
- Red for declined
- Clear status indicators

### ✅ Balance Tracking
- Automatic calculation from all expenses
- Real-time updates
- Considers all unsettled transactions

### ✅ Two-Way Communication
- Either user can initiate
- Request-approval workflow
- Transparent process

## Database Structure

### Settlement Request Message
```javascript
{
  text: "Settlement request for ₹500.00",
  senderId: "requester_uid",
  senderName: "John",
  timestamp: Timestamp,
  type: "settlement_request",
  amount: 500,
  isSettlementRequest: true,
  status: "pending", // or "approved" or "rejected"
  requesterId: "requester_uid",
  payerId: "payer_uid"
}
```

### Settlement Completed Message
```javascript
{
  text: "Payment of ₹500.00 settled",
  senderId: "payer_uid",
  senderName: "Jane",
  timestamp: Timestamp,
  type: "settlement",
  amount: 500,
  isSettlement: true
}
```

## Benefits Over Previous Version

### Before (One-Way Only)
- ❌ Only the person who owes could initiate
- ❌ Person owed money had to wait
- ❌ No way to request payment
- ❌ Button disabled for creditor

### After (Two-Way System)
- ✅ Either person can initiate
- ✅ Request-approval workflow
- ✅ Interactive chat messages
- ✅ Both users have control
- ✅ Clear communication
- ✅ Transparent process

## Tips for Users

1. **Check Balance First**: Look at the text above the button to see who owes whom

2. **Send Requests Politely**: Settlement requests are visible in chat, so they serve as gentle reminders

3. **Respond Promptly**: When you receive a request, respond quickly to maintain good relationships

4. **Decline Respectfully**: If you can't pay immediately, decline and communicate separately

5. **Verify Amounts**: Always check the amount before paying or requesting

## Troubleshooting

### "No payment needed" message
- Balance is already zero
- Refresh the screen by closing and reopening chat

### Request not showing buttons
- You might be the sender (requests only show buttons to recipient)
- Request might already be approved/declined

### UPI app not opening
- Ensure UPI app is installed
- Check internet connection
- Try different UPI app

### Balance not updating
- Close and reopen the chat screen
- Check internet connection
- Verify expenses are saved properly

## Future Enhancements

- [ ] Push notifications for settlement requests
- [ ] Reminder system for pending requests
- [ ] Payment history view
- [ ] Partial settlement support
- [ ] Multiple currency support
- [ ] Payment verification via UPI APIs
