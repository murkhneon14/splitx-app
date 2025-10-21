import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/subscription_billing_service.dart';

class SubscriptionScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<dynamic> members;

  const SubscriptionScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.members,
  }) : super(key: key);

  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Predefined subscription templates
  final List<Map<String, dynamic>> subscriptionTemplates = [
    {
      'name': 'Netflix',
      'icon': Icons.movie,
      'color': Colors.red,
      'suggestedPrice': 649.0,
      'description': 'Premium Plan - 4 screens',
    },
    {
      'name': 'YouTube Premium',
      'icon': Icons.play_circle_filled,
      'color': Colors.red.shade700,
      'suggestedPrice': 129.0,
      'description': 'Ad-free videos & music',
    },
    {
      'name': 'Spotify',
      'icon': Icons.music_note,
      'color': Colors.green,
      'suggestedPrice': 119.0,
      'description': 'Premium Individual',
    },
    {
      'name': 'Amazon Prime',
      'icon': Icons.shopping_bag,
      'color': Colors.blue.shade900,
      'suggestedPrice': 1499.0,
      'description': 'Annual subscription',
    },
    {
      'name': 'Disney+ Hotstar',
      'icon': Icons.star,
      'color': Colors.blue,
      'suggestedPrice': 1499.0,
      'description': 'Super Plan - Annual',
    },
    {
      'name': 'Apple Music',
      'icon': Icons.music_video,
      'color': Colors.pink,
      'suggestedPrice': 99.0,
      'description': 'Individual Plan',
    },
    {
      'name': 'Custom',
      'icon': Icons.add_circle_outline,
      'color': Colors.grey,
      'suggestedPrice': 0.0,
      'description': 'Create your own',
    },
  ];

  Future<void> _showAddSubscriptionDialog() async {
    Map<String, dynamic>? selectedTemplate;
    TextEditingController nameController = TextEditingController();
    TextEditingController priceController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    String billingCycle = 'Monthly';
    DateTime nextBillingDate = DateTime.now().add(Duration(days: 30));
    String? paidBy;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Subscription'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Template Selection
                  const Text(
                    'Choose a template:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: subscriptionTemplates.map((template) {
                      final isSelected = selectedTemplate == template;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedTemplate = template;
                            if (template['name'] != 'Custom') {
                              nameController.text = template['name'];
                              priceController.text = template['suggestedPrice'].toString();
                              descriptionController.text = template['description'];
                            } else {
                              nameController.clear();
                              priceController.clear();
                              descriptionController.clear();
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? template['color'] : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                template['icon'],
                                size: 16,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                template['name'],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  
                  // Subscription Details
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Subscription Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Price (₹)',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Billing Cycle
                  DropdownButtonFormField<String>(
                    value: billingCycle,
                    decoration: const InputDecoration(
                      labelText: 'Billing Cycle',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Monthly', 'Yearly', 'Quarterly']
                        .map((cycle) => DropdownMenuItem(
                              value: cycle,
                              child: Text(cycle),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        billingCycle = value!;
                        // Update next billing date based on cycle
                        if (billingCycle == 'Monthly') {
                          nextBillingDate = DateTime.now().add(Duration(days: 30));
                        } else if (billingCycle == 'Yearly') {
                          nextBillingDate = DateTime.now().add(Duration(days: 365));
                        } else if (billingCycle == 'Quarterly') {
                          nextBillingDate = DateTime.now().add(Duration(days: 90));
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Who pays
                  DropdownButtonFormField<String>(
                    value: paidBy,
                    decoration: const InputDecoration(
                      labelText: 'Who pays the bill?',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Select member'),
                    items: widget.members.map<DropdownMenuItem<String>>((member) {
                      String memberId;
                      String memberName;
                      
                      if (member is Map<String, dynamic>) {
                        memberId = member['id'] ?? '';
                        memberName = member['username'] ?? 'Unknown';
                      } else {
                        memberId = member.toString();
                        memberName = member.toString();
                      }
                      
                      return DropdownMenuItem(
                        value: memberId,
                        child: Text(memberName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        paidBy = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Next billing date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Next Billing Date'),
                    subtitle: Text(DateFormat('MMM dd, yyyy').format(nextBillingDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: nextBillingDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          nextBillingDate = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty || priceController.text.isEmpty || paidBy == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all required fields')),
                    );
                    return;
                  }
                  
                  await _createSubscription(
                    name: nameController.text,
                    price: double.parse(priceController.text),
                    description: descriptionController.text,
                    billingCycle: billingCycle,
                    nextBillingDate: nextBillingDate,
                    paidBy: paidBy!,
                    icon: selectedTemplate?['icon'] ?? Icons.subscriptions,
                    color: selectedTemplate?['color'] ?? Colors.blue,
                  );
                  
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createSubscription({
    required String name,
    required double price,
    required String description,
    required String billingCycle,
    required DateTime nextBillingDate,
    required String paidBy,
    required IconData icon,
    required Color color,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Calculate per-person cost
      final perPersonCost = price / widget.members.length;

      // Get payer's name
      String payerName = 'Unknown';
      for (var member in widget.members) {
        if (member is Map<String, dynamic>) {
          if (member['id'] == paidBy) {
            payerName = member['username'] ?? 'Unknown';
            break;
          }
        }
      }

      await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('subscriptions')
          .add({
        'name': name,
        'totalPrice': price,
        'perPersonCost': perPersonCost,
        'description': description,
        'billingCycle': billingCycle,
        'nextBillingDate': Timestamp.fromDate(nextBillingDate),
        'paidBy': paidBy,
        'payerName': payerName,
        'iconCodePoint': icon.codePoint,
        'colorValue': color.value,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'members': widget.members.map((m) => m is Map ? m['id'] : m).toList(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subscription "$name" created successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error creating subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create subscription')),
        );
      }
    }
  }

  Future<void> _toggleSubscriptionStatus(String subscriptionId, bool currentStatus) async {
    try {
      await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('subscriptions')
          .doc(subscriptionId)
          .update({
        'isActive': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error toggling subscription: $e');
    }
  }

  Future<void> _deleteSubscription(String subscriptionId) async {
    try {
      await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('subscriptions')
          .doc(subscriptionId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription deleted')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting subscription: $e');
    }
  }

  Future<void> _sendManualBillingReminder(String subscriptionId) async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sending billing reminder...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final billingService = SubscriptionBillingService();
      await billingService.sendManualBillingReminder(
        groupId: widget.groupId,
        subscriptionId: subscriptionId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Billing reminder sent to group chat!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending manual billing reminder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send billing reminder'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getDaysUntilBilling(Timestamp nextBillingDate) {
    final now = DateTime.now();
    final billingDate = nextBillingDate.toDate();
    final difference = billingDate.difference(now).inDays;
    
    if (difference < 0) {
      return 'Overdue';
    } else if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else {
      return 'in $difference days';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF3E0),
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: Text('${widget.groupName} - Subscriptions'),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('groups')
            .doc(widget.groupId)
            .collection('subscriptions')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final subscriptions = snapshot.data?.docs ?? [];

          if (subscriptions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.subscriptions, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No subscriptions yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add Netflix, Spotify, or any shared subscription',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Calculate total monthly cost
          double totalMonthlyCost = 0;
          double yourMonthlyCost = 0;

          for (var doc in subscriptions) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['isActive'] == true) {
              final price = (data['totalPrice'] ?? 0).toDouble();
              final billingCycle = data['billingCycle'] ?? 'Monthly';
              
              // Convert to monthly cost
              double monthlyCost = price;
              if (billingCycle == 'Yearly') {
                monthlyCost = price / 12;
              } else if (billingCycle == 'Quarterly') {
                monthlyCost = price / 3;
              }
              
              totalMonthlyCost += monthlyCost;
              yourMonthlyCost += monthlyCost / widget.members.length;
            }
          }

          return Column(
            children: [
              // Summary Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Colors.deepOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Monthly Cost',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            Text(
                              '₹${totalMonthlyCost.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Your Share',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            Text(
                              '₹${yourMonthlyCost.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${subscriptions.where((s) => (s.data() as Map)['isActive'] == true).length} active subscriptions',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              // Subscriptions List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: subscriptions.length,
                  itemBuilder: (context, index) {
                    final doc = subscriptions[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isActive = data['isActive'] ?? true;
                    
                    final colorValue = data['colorValue'] as int? ?? Colors.blue.value;
                    const icon = IconData(0xe530, fontFamily: 'MaterialIcons'); // subscriptions icon
                    final color = Color(colorValue);

                    final nextBillingDate = data['nextBillingDate'] as Timestamp?;
                    final daysUntil = nextBillingDate != null 
                        ? _getDaysUntilBilling(nextBillingDate)
                        : 'N/A';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isActive ? 2 : 0,
                      color: isActive ? Colors.white : Colors.grey.shade200,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: color, size: 28),
                        ),
                        title: Text(
                          data['name'] ?? 'Subscription',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isActive ? Colors.black : Colors.grey,
                            decoration: isActive ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '₹${data['totalPrice']} / ${data['billingCycle']}',
                              style: TextStyle(
                                color: isActive ? Colors.black87 : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '₹${(data['perPersonCost'] ?? 0).toStringAsFixed(2)} per person',
                              style: TextStyle(
                                color: isActive ? Colors.grey.shade600 : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.person, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  'Paid by ${data['payerName']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            if (isActive && nextBillingDate != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 12,
                                      color: daysUntil == 'Overdue' ? Colors.red : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Next billing $daysUntil',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: daysUntil == 'Overdue' ? Colors.red : Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          icon: const Icon(Icons.more_vert),
                          itemBuilder: (context) => [
                            if (isActive)
                              PopupMenuItem(
                                value: 'send_reminder',
                                child: Row(
                                  children: [
                                    Icon(Icons.notifications_active, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('Send Billing Reminder'),
                                  ],
                                ),
                              ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Row(
                                children: [
                                  Icon(
                                    isActive ? Icons.pause_circle : Icons.play_circle,
                                    color: Colors.black87,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(isActive ? 'Pause' : 'Activate'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'send_reminder') {
                              await _sendManualBillingReminder(doc.id);
                            } else if (value == 'toggle') {
                              _toggleSubscriptionStatus(doc.id, isActive);
                            } else if (value == 'delete') {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Subscription'),
                                  content: const Text('Are you sure you want to delete this subscription?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _deleteSubscription(doc.id);
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSubscriptionDialog,
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add),
        label: const Text('Add Subscription'),
      ),
    );
  }
}
