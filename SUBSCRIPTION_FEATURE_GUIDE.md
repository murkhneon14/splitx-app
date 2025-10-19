# 📱 Subscription Sharing Feature Guide

## Overview
The Subscription Sharing feature makes it easy to manage recurring expenses like Netflix, YouTube Premium, Spotify, and other shared subscriptions within your groups. No more manual calculations or forgotten payments!

## ✨ Key Features

### 1. **Predefined Templates**
Quick-add popular subscriptions with pre-filled prices:
- 🎬 **Netflix** - ₹649/month (Premium Plan - 4 screens)
- ▶️ **YouTube Premium** - ₹129/month
- 🎵 **Spotify** - ₹119/month (Premium Individual)
- 📦 **Amazon Prime** - ₹1499/year
- ⭐ **Disney+ Hotstar** - ₹1499/year (Super Plan)
- 🎵 **Apple Music** - ₹99/month
- ➕ **Custom** - Create your own subscription

### 2. **Automatic Cost Splitting**
- Automatically divides the total cost among all group members
- Shows per-person cost clearly
- Converts yearly/quarterly costs to monthly equivalents for easy comparison

### 3. **Billing Cycle Management**
- Support for Monthly, Yearly, and Quarterly billing cycles
- Next billing date tracking
- Visual countdown showing days until next payment
- Overdue notifications

### 4. **Smart Organization**
- Track who pays the bill
- Active/Inactive subscription status
- Total monthly cost summary
- Your personal share calculation

## 🚀 How to Use

### Creating a Subscription

1. **Access Subscriptions**
   - From **Group List**: Tap the three-dot menu (⋮) on any group → Select "Subscriptions"
   - From **Group Chat**: Tap the subscription icon (🔔) in the top-right corner

2. **Add New Subscription**
   - Tap the orange "Add Subscription" button
   - Choose a template or select "Custom"

3. **Fill in Details**
   - **Subscription Name**: Auto-filled for templates, or enter your own
   - **Total Price**: The full subscription cost
   - **Description**: Optional details (e.g., "Family Plan", "Premium")
   - **Billing Cycle**: Monthly, Yearly, or Quarterly
   - **Who pays the bill**: Select the group member who makes the payment
   - **Next Billing Date**: When the next payment is due

4. **Create**
   - Tap "Create" to save the subscription
   - It will appear in the group's subscription list

### Managing Subscriptions

#### View Summary
At the top of the subscription screen, you'll see:
- **Total Monthly Cost**: Combined cost of all active subscriptions (converted to monthly)
- **Your Share**: Your portion of the total cost
- **Active Subscriptions Count**: Number of currently active subscriptions

#### Subscription Actions
Tap the three-dot menu (⋮) on any subscription to:
- **Pause/Activate**: Temporarily disable a subscription without deleting it
- **Delete**: Permanently remove the subscription

#### Subscription Card Details
Each subscription shows:
- Service icon and name
- Total price and billing cycle
- Per-person cost
- Who pays the bill
- Days until next billing (with color-coded alerts)

## 💡 Use Cases

### Example 1: Netflix Sharing
**Group**: "College Friends" (4 members)
- **Subscription**: Netflix Premium
- **Total Cost**: ₹649/month
- **Per Person**: ₹162.25/month
- **Paid by**: Rahul
- **Next Billing**: in 15 days

Everyone in the group can see:
- They owe Rahul ₹162.25 this month
- When the next payment is due
- The total group cost

### Example 2: Multiple Subscriptions
**Group**: "Roommates" (3 members)
- Netflix (₹649/month) - Paid by Priya
- Spotify (₹119/month) - Paid by Amit
- Amazon Prime (₹1499/year = ₹124.92/month) - Paid by Neha

**Total Monthly**: ₹892.92
**Your Share**: ₹297.64/month

### Example 3: Annual Subscription
**Group**: "Family" (5 members)
- **Subscription**: Disney+ Hotstar Super
- **Total Cost**: ₹1499/year
- **Billing Cycle**: Yearly
- **Converted to Monthly**: ₹124.92/month
- **Per Person**: ₹24.98/month

## 🎯 Best Practices

1. **Set Accurate Billing Dates**
   - Use the actual renewal date for better tracking
   - The app will show countdown reminders

2. **Update Subscription Status**
   - Pause subscriptions during inactive periods
   - Delete subscriptions you no longer use

3. **Regular Reviews**
   - Check the subscription list monthly
   - Ensure everyone has paid their share
   - Update prices if plans change

4. **Clear Communication**
   - Use the group chat to discuss subscription changes
   - Notify members before adding new subscriptions
   - Confirm payment receipt

## 📊 Understanding Costs

### Monthly View
All costs are normalized to monthly amounts for easy comparison:
- **Monthly subscriptions**: Shown as-is
- **Yearly subscriptions**: Divided by 12
- **Quarterly subscriptions**: Divided by 3

### Your Share Calculation
```
Your Share = (Total Monthly Cost of All Active Subscriptions) / (Number of Group Members)
```

## 🔔 Billing Reminders

The app shows visual indicators for upcoming payments:
- **Orange**: Next billing in X days
- **Red**: Overdue payment

## ⚙️ Technical Details

### Data Storage
- Subscriptions are stored per group in Firestore
- Real-time updates across all group members
- Automatic synchronization

### Supported Billing Cycles
- Monthly (30 days)
- Quarterly (90 days)
- Yearly (365 days)

## 🆘 Troubleshooting

**Q: I don't see the subscription button**
- Make sure you're in a group chat (not a 1:1 chat)
- Check that you're a member of the group

**Q: Can I edit a subscription after creating it?**
- Currently, you need to delete and recreate
- Future updates will add edit functionality

**Q: What happens if someone leaves the group?**
- The per-person cost automatically recalculates
- Update the "Who pays" field if needed

**Q: Can I track payment history?**
- This feature is coming in a future update
- For now, use the group chat to confirm payments

## 🎉 Benefits

1. **No More Mental Math**: Automatic cost splitting
2. **Never Forget Payments**: Visual billing reminders
3. **Fair Distribution**: Equal sharing among all members
4. **Transparency**: Everyone sees the same information
5. **Easy Management**: Add, pause, or delete subscriptions anytime

## 📱 Quick Access

- **From Groups Tab**: Menu → Subscriptions
- **From Group Chat**: Subscription icon in AppBar

---

**Made with ❤️ for easy expense sharing**
