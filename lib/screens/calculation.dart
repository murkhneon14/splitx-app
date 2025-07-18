import 'package:flutter/material.dart';
import '../widgets/custom_bottom_nav.dart';
import 'NewExpense.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../utils/chat_utils.dart';

// Import SetOptions from cloud_firestore
import 'package:cloud_firestore/cloud_firestore.dart' show SetOptions;

// Make sure these dependencies are in your pubspec.yaml:
// dependencies:
//   flutter:
//     sdk: flutter
//   firebase_core: ^2.15.1
//   cloud_firestore: ^4.9.1
//   firebase_auth: ^4.9.0
//   intl: ^0.18.1
//   shared_preferences: ^2.2.2

class ExpenseSplitApp extends StatelessWidget {
  final List<Map<String, dynamic>> selectedFriends;

  const ExpenseSplitApp({super.key, required this.selectedFriends});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ExpenseSplitScreen(selectedFriends: selectedFriends),
    );
  }
}

class ExpenseSplitScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedFriends;

  const ExpenseSplitScreen({super.key, required this.selectedFriends});

  @override
  _ExpenseSplitScreenState createState() => _ExpenseSplitScreenState();
}

class _ExpenseSplitScreenState extends State<ExpenseSplitScreen> {
  late List<Map<String, dynamic>> members;
  TextEditingController totalAmountController = TextEditingController();
  TextEditingController _expenseController = TextEditingController();
  bool isCustomSplit = false;
  String? selectedPayer;
  String savedExpense = "";
  String savedAmount = "";
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    if (savedAmount.isNotEmpty) {
      totalAmountController.text = savedAmount;
    }
    
    // Initialize expense controller with saved expense if it exists
    if (savedExpense.isNotEmpty && savedExpense != "No Expense") {
      _expenseController.text = savedExpense;
    }

    // Initialize members list from selectedFriends with null safety
    members =
        (widget.selectedFriends ?? []).map<Map<String, dynamic>>((friend) {
          if (friend != null) {
            return {
              "name": friend["username"]?.toString() ?? 'Unknown',
              "id": friend["id"]?.toString() ?? '',
              "selected": true,
              "amount": 0.0,
              "controller": TextEditingController(),
            };
          }
          return {
            "name": 'Unknown',
            "id": '',
            "selected": true,
            "amount": 0.0,
            "controller": TextEditingController(),
          };
        }).toList();

    // Set the first member as the default payer if available
    if (members.isNotEmpty && members.first["name"] != null) {
      selectedPayer = members.first["name"];
    } else {
      selectedPayer = 'You'; // Default payer name if no members
    }

    loadSavedData();
  }

  Future<void> _clearExpenseOnRestart() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('savedExpense'); // Remove saved value
    setState(() {
      _expenseController.clear(); // Clear the text field
    });
  }

  Future<void> loadSavedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      savedExpense = prefs.getString("expense") ?? "No Expense";
      savedAmount = prefs.getString("amount") ?? "0";
    });
  }

  void splitAmount() {
    double totalAmount = double.tryParse(totalAmountController.text) ?? 0;
    final selectedMembers = members.where((m) => m["selected"]).toList();
    int selectedCount = selectedMembers.length;
    
    if (selectedCount > 0 && !isCustomSplit) {
      // Calculate the base amount and round to 2 decimal places
      double baseAmount = totalAmount / selectedCount;
      double roundedBase = double.parse(baseAmount.toStringAsFixed(2));
      
      // Calculate the total if we used rounded amounts for all but the last person
      double runningTotal = 0;
      List<double> amounts = [];
      
      // For all but the last person, use the rounded amount
      for (int i = 0; i < selectedCount - 1; i++) {
        amounts.add(roundedBase);
        runningTotal += roundedBase;
      }
      
      // For the last person, use the remaining amount to ensure exact total
      double lastAmount = (totalAmount * 100).roundToDouble() / 100 - runningTotal;
      amounts.add(lastAmount);
      
      setState(() {
        // Update amounts for selected members
        for (int i = 0; i < selectedMembers.length; i++) {
          var member = selectedMembers[i];
          double amount = amounts[i];
          
          // Ensure we don't have negative amounts
          if (amount < 0) amount = 0;
          
          member["amount"] = amount;
          member["controller"].text = amount.toStringAsFixed(2);
        }
        
        // Clear amounts for unselected members
        for (var member in members) {
          if (!member["selected"]) {
            member["amount"] = 0.0;
            member["controller"].clear();
          }
        }
      });
    }
  }

  // Track loading state
  bool _isSaving = false;

  // Send expense notification to all participants and save expense history
  Future<bool> _sendExpenseNotifications() async {
    if (_isSaving) return false; // Prevent multiple saves

    setState(() {
      _isSaving = true;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You must be logged in to save expenses'),
            ),
          );
        }
      }
      return false;
    }

    try {
      final expenseName = _expenseController.text.isNotEmpty
          ? _expenseController.text
          : 'a shared expense';
      final totalAmount = double.tryParse(totalAmountController.text) ?? 0;
      final formatter = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();

      // Create a unique ID for this expense
      final expenseRef = FirebaseFirestore.instance.collection('expenses').doc();
      final expenseId = expenseRef.id;

      // Prepare expense data for history
      final Map<String, dynamic> expenseData = {
        'id': expenseId,
        'description': expenseName,
        'amount': totalAmount,
        'payerId': currentUser.uid,
        'payerName': currentUser.displayName ?? 'You',
        'timestamp': now,
        'participants': [],
        'shares': {},
      };

      // Get all selected members (including payer)
      final selectedMembers = members.where((m) => m["selected"] == true).toList();
      
      if (selectedMembers.length < 2) {
        if (mounted) {
          setState(() => _isSaving = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select at least one other person')),
            );
          }
        }
        return false;
      }
      
      // Add participants to expense data
      final List<String> participantIds = [];
      final Map<String, double> shares = {};
      
      for (var member in selectedMembers) {
        final String? memberId = member['id']?.toString();
        if (memberId != null && memberId.isNotEmpty) {
          participantIds.add(memberId);
          final amount = (member['amount'] as num?)?.toDouble() ?? 0.0;
          shares[memberId] = amount;
        }
      }
      
      // Update expense data with participants and shares
      expenseData['participants'] = participantIds;
      expenseData['shares'] = shares;
      
      // Save the expense to Firestore with payer's name
      await expenseRef.set({
        ...expenseData,
        'payerName': currentUser.displayName ?? 'You',  // Ensure payerName is set in main document
      });
      
      // Add the expense to the payer's history
      await _firestore.collection('userExpenses')
          .doc(currentUser.uid)
          .collection('expenses')
          .doc(expenseId)
          .set({
            'expenseId': expenseId,
            'amount': totalAmount,
            'description': expenseName,
            'isPayer': true,
            'timestamp': now,
            'participantCount': participantIds.length - 1, // Exclude self
          });
          
      // Add the expense to each participant's history
      for (var participantId in participantIds) {
        if (participantId != currentUser.uid) { // Skip self for participants
          await _firestore.collection('userExpenses')
              .doc(participantId)
              .collection('expenses')
              .doc(expenseId)
              .set({
                'expenseId': expenseId,
                'amount': shares[participantId] ?? 0,
                'description': expenseName,
                'isPayer': false,
                'timestamp': now,
                'payerName': currentUser.displayName ?? 'You',  // Use consistent 'You' instead of 'Someone'
                'payerId': currentUser.uid,
              });
        }
      }

      // Process each selected member who is not the payer for notifications
      for (var member in selectedMembers) {
        if (member['id']?.toString() == currentUser.uid) continue; // Skip self for notifications
        
        final amount = member["amount"] is double ? member["amount"] : 0.0;
        final String? recipientId = member['id']?.toString();
        final String? recipientName = member['name']?.toString();

        if (recipientId == null || recipientId.isEmpty) continue;

        // Create a chat ID that's consistent between the two users
        final chatId = _createChatId(currentUser.uid, recipientId);

        // Create a reference to the messages subcollection
        final messagesCollection = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages');

        // Create a new message document
        final messageDoc = messagesCollection.doc();

        // Format the message as requested
        final message =
            '$selectedPayer paid ${formatter.format(totalAmount)} for $expenseName.\nYour share is ${formatter.format(amount)}.';

        // Create the message data
        final messageData = {
          'text': '${currentUser.displayName ?? 'Someone'} paid ₹${totalAmount.toStringAsFixed(2)} for $expenseName',
          'senderId': currentUser.uid,
          'senderName': currentUser.displayName ?? 'You',
          'timestamp': now,
          'type': 'expense',
          'expenseId': expenseId,
          'amount': totalAmount,
          'userShare': amount, // Add user's share amount
          'description': expenseName,
          'expenseName': expenseName,
          'payer': selectedPayer,
          'payerId': currentUser.uid, // Add payerId for easier reference
          'recipientId': recipientId,
          'recipientName': recipientName,
          'isExpense': true,
          'isPaymentRequest': true,
          'paymentAmount': amount,
          'paymentStatus': 'pending',
        };

        // Add the message to the batch
        debugPrint('Adding message to batch for chat: $chatId');
        batch.set(messageDoc, messageData);

        // Update the chat metadata
        final chatMetadataRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId);

        debugPrint('Updating chat metadata for: $chatId');
        debugPrint('Participants: ${[currentUser.uid, recipientId]}');

        // Create or update the chat metadata
        batch.set(chatMetadataRef, {
          'lastMessage': message,
          'lastMessageTime': now,
          'participants': [currentUser.uid, recipientId]..sort(),
          'participantNames': {
            currentUser.uid: currentUser.displayName ?? 'User',
            recipientId: recipientName ?? 'User',
          },
          'updatedAt': now,
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Commit all changes in a single batch
      await batch.commit();

      if (!mounted) return false;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense saved and notifications sent'),
          duration: Duration(seconds: 2),
        ),
      );

      // Clear the form
      _expenseController.clear();
      totalAmountController.clear();
      for (var member in members) {
        member['selected'] = false;
        member['amount'] = 0.0;
        if (member['controller'] is TextEditingController) {
          member['controller'].clear();
        }
      }

      // Navigate back to previous screen
      if (mounted) {
        Navigator.of(context).pop(true); // Pass true to indicate success
      }
      return true; // Success
    } catch (e) {
      debugPrint('Error sending notifications: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save expense. Please try again.'),
            ),
          );
        }
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Helper method to create a consistent chat ID between two users
  String _createChatId(String uid1, String uid2) {
    return ChatUtils.generateChatId(uid1, uid2);
  }

  Future<bool> validateCustomSplit(BuildContext context) async {
    double totalEntered = 0;
    double totalAmount = double.tryParse(totalAmountController.text) ?? 0;
    bool hasError = false;

    for (var member in members) {
      if (member["selected"]) {
        String amountText = member["controller"].text.trim();
        if (amountText.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter amount for all selected members'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          return false;
        }

        double? amount = double.tryParse(amountText);
        if (amount == null) {
          hasError = true;
          break;
        }
        totalEntered += amount;
      }
    }

    if (hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Error: Please enter valid numbers in all amount fields',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
      return false;
    }

    // Compare with a small epsilon to handle floating point precision issues
    const epsilon = 0.01;
    if ((totalEntered - totalAmount).abs() > epsilon) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final formatter = NumberFormat.currency(symbol: '₹');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Total must be exactly ${formatter.format(totalAmount)}. Current total: ${formatter.format(totalEntered)}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Show message if no members are selected
    if (members.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No members selected. Please go back and select at least one member.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFFAF3E0),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NewExpenseScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                    ),
                    onPressed:
                        _isSaving
                            ? null
                            : () async {
                              // Show loading indicator first
                              if (!mounted) return;

                              // Validate the split
                              final isValid = await validateCustomSplit(
                                context,
                              );
                              if (!isValid || !mounted) return;

                              // Show loading dialog
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder:
                                    (BuildContext context) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                              );

                              try {
                                // Send notifications
                                await _sendExpenseNotifications();

                                // Close loading dialog
                                if (mounted) {
                                  Navigator.of(context).pop();
                                  // Go back to home screen
                                  Navigator.of(
                                    context,
                                  ).popUntil((route) => route.isFirst);
                                }
                              } catch (e) {
                                // Close loading dialog on error
                                if (mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Failed to save expense. Please try again.',
                                      ),
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            },
                    child: const Text(
                      "Save Expense",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 5,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.shopping_basket,
                                color: Colors.green,
                                size: 40,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _expenseController,
                                  onChanged: (value) {
                                    setState(() {
                                      savedExpense = value;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: "Add a new expense",
                                    hintStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  keyboardType: TextInputType.text,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                            ],
                          ),
                          Divider(),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: totalAmountController,

                                  decoration: InputDecoration(
                                    hintText: "Confirm Amount",
                                    hintStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      savedAmount = value;
                                    });
                                    splitAmount();
                                  },
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              DropdownButton<String>(
                                items:
                                    ["INR", "USD", "EUR"]
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (val) {},
                                hint: Text("INR"),
                              ),
                            ],
                          ),
                          Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Paid by",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              DropdownButton<String>(
                                value: selectedPayer,
                                items:
                                    (members ?? []).map((member) {
                                      return DropdownMenuItem<String>(
                                        value: member["name"] ?? "",
                                        child: Text(
                                          member["name"] ?? "Unknown",
                                        ),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedPayer = value;
                                  });
                                },
                                hint: const Text("Select Payer"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    SwitchListTile(
                      title: const Text("Custom Split"),
                      value: isCustomSplit,
                      onChanged: (value) {
                        setState(() {
                          isCustomSplit = value;
                          if (!isCustomSplit) {
                            splitAmount();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Add a null check for members list
            if (members == null || members.isEmpty)
              const Center(child: Text('No members selected'))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    // Ensure valid index
                    if (index < 0 || index >= members.length) {
                      return const SizedBox.shrink();
                    }

                    var member = members[index];
                    if (member == null || member["name"] == null) {
                      return const SizedBox.shrink();
                    }

                    return ListTile(
                      title: Text(member["name"]?.toString() ?? "Unknown"),
                      trailing: SizedBox(
                        width: 100,
                        child:
                            isCustomSplit
                                ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.grey,
                                      width: 0.5,
                                    ),
                                  ),

                                  child: TextField(
                                    controller: member["controller"],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                    ),
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold, // Bold when custom split
                                      fontSize: 16,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        double enteredAmount =
                                            double.tryParse(value) ?? 0;
                                        double totalAmount =
                                            double.tryParse(
                                              totalAmountController.text,
                                            ) ??
                                            0;

                                        // Ensure valid input
                                        if (enteredAmount < 0) {
                                          member["controller"]
                                              .text = member["amount"]
                                              .toStringAsFixed(2);
                                          return;
                                        }

                                        // Update the edited member's amount
                                        member["amount"] = enteredAmount;
                                        member["manual"] =
                                            true; // Mark this member as manually edited

                                        // Get manually edited and unedited members separately
                                        List<Map<String, dynamic>>
                                        manuallyEdited =
                                            members
                                                .where(
                                                  (m) => m["manual"] == true,
                                                )
                                                .toList();
                                        List<Map<String, dynamic>>
                                        uneditedMembers =
                                            members
                                                .where(
                                                  (m) =>
                                                      m["manual"] != true &&
                                                      m["selected"],
                                                )
                                                .toList();

                                        // Calculate total manually entered amount
                                        double totalEntered = manuallyEdited
                                            .fold(
                                              0,
                                              (sum, m) =>
                                                  sum + (m["amount"] ?? 0),
                                            );

                                        // Prevent exceeding total
                                        if (totalEntered > totalAmount) {
                                          member["amount"] = 0;
                                          member["controller"].text = "";
                                          return;
                                        }

                                        // Remaining amount to be split
                                        double remainingAmount =
                                            totalAmount - totalEntered;
                                        int remainingMembers =
                                            uneditedMembers.length;

                                        if (remainingMembers > 0) {
                                          double splitAmount =
                                              remainingAmount /
                                              remainingMembers;

                                          for (var m in uneditedMembers) {
                                            m["amount"] = splitAmount;
                                            m["controller"].text = splitAmount
                                                .toStringAsFixed(2);
                                          }
                                        }
                                      });
                                    },
                                  ),
                                )
                                : Text(
                                  "₹${member["amount"].toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold, // Bold when equally split
                                    fontSize: 16,
                                    color: Colors.green,
                                  ),
                                ),
                      ),

                      leading: Checkbox(
                        value: member["selected"],
                        onChanged: (value) {
                          setState(() {
                            member["selected"] = value!;
                            if (!isCustomSplit) splitAmount();
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 2),
    );
  }
}
