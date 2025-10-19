# 🔔 Automated Subscription Billing Guide

## Overview
The automated billing system sends payment reminders directly to group chats on the day subscriptions are due, making it easy for members to pay their share with just a few taps.

## ✨ Key Features

### 1. **Automated Billing Messages**
- Automatically sent to group chat on billing day
- Shows subscription details and per-person cost
- Includes direct payment buttons
- Updates next billing date automatically

### 2. **Manual Billing Reminders**
- Send reminders anytime from subscription menu
- Useful for early reminders or payment follow-ups
- Same format as automated reminders

### 3. **One-Tap Payment**
- "Pay Now" button launches UPI app with pre-filled details
- Amount, recipient, and note automatically populated
- Payment confirmation workflow built-in

### 4. **Payment Tracking**
- Members can confirm payments in chat
- Payer receives confirmation notifications
- Full transparency for all group members

## 🚀 How It Works

### Automated Billing Flow

1. **Billing Day Arrives**
   - System checks all active subscriptions daily
   - Identifies subscriptions due today
   - Sends billing message to group chat

2. **Members Receive Notification**
   - Beautiful billing card appears in chat
   - Shows:
     - Subscription name (e.g., Netflix)
     - Total amount and billing cycle
     - Your personal share
     - Who to pay

3. **One-Tap Payment**
   - Member taps "Pay Now" button
   - UPI app opens with pre-filled payment details
   - Complete payment in UPI app
   - Return to SplitX

4. **Confirm Payment**
   - Dialog asks: "Did you complete the payment?"
   - Tap "Yes, Paid"
   - Confirmation sent to group chat
   - Payer can see who has paid

5. **Next Billing Date Updated**
   - System automatically calculates next billing date
   - Based on billing cycle (Monthly/Quarterly/Yearly)
   - Process repeats next billing day

### Manual Reminder Flow

1. **Open Subscription Screen**
   - Navigate to group → Subscriptions
   - Find the subscription

2. **Send Reminder**
   - Tap three-dot menu (⋮) on subscription
   - Select "Send Billing Reminder"
   - Instant reminder sent to group chat

3. **Same Payment Flow**
   - Members follow same payment process
   - Works exactly like automated reminders

## 📱 Billing Message Features

### For Non-Payers (Members who need to pay)

**Billing Card Shows:**
- 🔔 Subscription name and icon
- 💰 Total amount and your share
- 👤 Who to pay
- 📅 Billing cycle

**Action Buttons:**
- **Pay Now** (Green) - Opens UPI with pre-filled details
- **Open UPI** (Orange) - Opens UPI app directly

**Payment Flow:**
1. Tap "Pay Now"
2. UPI app opens (GPay, PhonePe, Paytm, etc.)
3. Verify details and complete payment
4. Return to app
5. Confirm payment in dialog
6. Confirmation sent to chat

### For Payers (Member who paid the bill)

**Billing Card Shows:**
- Same subscription details
- Green info box: "You are the payer. Others will pay you their share."
- No payment buttons (you already paid)

**Benefits:**
- See who has paid via confirmation messages
- Track pending payments
- Full transparency

## 💡 Example Scenarios

### Scenario 1: Netflix Monthly Billing

**Setup:**
- Group: "Roommates" (4 members)
- Subscription: Netflix Premium
- Total: ₹649/month
- Payer: Rahul
- Next Billing: 15th of every month

**On 15th:**
1. **Automated message sent to group chat:**
   ```
   🔔 Subscription Billing Reminder
   
   📺 Netflix
   💰 Total: ₹649.00 / Monthly
   👥 Your share: ₹162.25
   💳 Pay to: Rahul
   ```

2. **Each member (except Rahul):**
   - Sees the billing card
   - Taps "Pay Now"
   - UPI opens with:
     - Amount: ₹162.25
     - To: Rahul's UPI ID
     - Note: "Subscription: Netflix"
   - Completes payment
   - Confirms in app

3. **Rahul sees:**
   - 3 payment confirmation messages
   - Knows who has paid
   - Can follow up with anyone who hasn't

4. **System automatically:**
   - Updates next billing date to 15th next month
   - Will send reminder again on that date

### Scenario 2: Yearly Subscription

**Setup:**
- Group: "Family" (5 members)
- Subscription: Amazon Prime
- Total: ₹1499/year
- Payer: Mom
- Next Billing: Jan 1st

**On Jan 1st:**
1. **Automated reminder sent**
2. **Each member pays:** ₹299.80 (₹1499 ÷ 5)
3. **Next billing:** Automatically set to Jan 1st next year

### Scenario 3: Manual Reminder

**Situation:** Netflix billing is in 5 days, but you want to remind members early

**Steps:**
1. Open Subscriptions screen
2. Find Netflix subscription
3. Tap ⋮ menu
4. Select "Send Billing Reminder"
5. Reminder instantly sent to chat
6. Members can pay early

## 🎯 Best Practices

### For Group Admins

1. **Set Accurate Billing Dates**
   - Use actual renewal dates
   - System will send reminders on those dates

2. **Ensure Payer Has UPI ID**
   - Payer must set UPI ID in profile
   - Required for "Pay Now" button to work

3. **Send Manual Reminders When Needed**
   - Early reminders before billing day
   - Follow-ups for pending payments
   - After adding new members

4. **Monitor Payment Confirmations**
   - Check group chat for confirmations
   - Follow up with members who haven't paid

### For Group Members

1. **Set Up UPI**
   - Ensure UPI apps are installed
   - Keep them updated

2. **Respond to Reminders Promptly**
   - Pay on billing day if possible
   - Confirm payment in app

3. **Check Billing Cards Carefully**
   - Verify amount before paying
   - Ensure you're paying the right person

4. **Keep UPI ID Updated**
   - If you're a payer, keep your UPI ID current
   - Update in Profile → UPI ID

## 🔧 Technical Details

### Billing Message Structure

```dart
{
  'type': 'subscription_billing',
  'subscriptionName': 'Netflix',
  'totalAmount': 649.0,
  'perPersonAmount': 162.25,
  'paidBy': 'userId123',
  'payerName': 'Rahul',
  'billingCycle': 'Monthly',
  'isSubscriptionBilling': true,
  'timestamp': serverTimestamp,
}
```

### Payment Confirmation Structure

```dart
{
  'type': 'subscription_payment_confirmation',
  'amount': 162.25,
  'subscriptionName': 'Netflix',
  'recipientId': 'payerId',
  'status': 'pending',
  'isPaymentConfirmation': true,
  'timestamp': serverTimestamp,
}
```

### Billing Date Calculation

**Monthly:**
```
Next Date = Current Date + 1 month
Example: Jan 15 → Feb 15
```

**Quarterly:**
```
Next Date = Current Date + 3 months
Example: Jan 15 → Apr 15
```

**Yearly:**
```
Next Date = Current Date + 1 year
Example: Jan 15, 2025 → Jan 15, 2026
```

## 🔔 Notification System

### Automated Checks
- System checks subscriptions daily
- Identifies due subscriptions
- Sends reminders automatically
- Updates next billing dates

### Manual Triggers
- Available from subscription menu
- Instant delivery to group chat
- No limit on manual reminders

## 📊 Payment Tracking

### For Payers

**See who has paid:**
- Payment confirmation messages in chat
- Shows member name and amount
- Timestamp for each payment

**Track pending payments:**
- Count confirmation messages
- Compare with group member count
- Follow up as needed

### For Members

**Confirm your payment:**
- After UPI payment completes
- Return to app
- Tap "Yes, Paid" in dialog
- Confirmation sent automatically

## 🆘 Troubleshooting

**Q: Billing reminder not sent automatically**
- Check subscription is active
- Verify next billing date is set
- Ensure subscription hasn't been paused

**Q: "Pay Now" button doesn't work**
- Payer must have UPI ID set in profile
- Check internet connection
- Ensure UPI app is installed

**Q: UPI app doesn't open**
- Install a UPI app (GPay, PhonePe, Paytm)
- Grant necessary permissions
- Try "Open UPI" button instead

**Q: Payment confirmation not sending**
- Check internet connection
- Ensure you're still in the group
- Try sending again from chat

**Q: Wrong billing date**
- Edit subscription (coming soon)
- Or delete and recreate with correct date

## 🎉 Benefits

### For Groups
✅ **No forgotten payments** - Automatic reminders  
✅ **Easy tracking** - See who has paid  
✅ **Full transparency** - Everyone sees the same info  
✅ **Reduced friction** - One-tap payments  
✅ **Automatic scheduling** - Set and forget  

### For Payers
✅ **Easy collection** - Members pay directly  
✅ **Payment tracking** - Confirmation messages  
✅ **No manual reminders** - System handles it  
✅ **UPI integration** - Receive payments instantly  

### For Members
✅ **Never miss payments** - Automatic reminders  
✅ **One-tap payment** - Pre-filled UPI details  
✅ **Clear amounts** - Know exactly what to pay  
✅ **Payment history** - Confirmations in chat  

## 🚀 Future Enhancements

- Payment history tracking
- Overdue payment notifications
- Payment analytics and insights
- Split payment options
- Recurring payment automation
- Integration with more payment methods

---

**Made with ❤️ for hassle-free subscription sharing**
