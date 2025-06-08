import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_bottom_nav.dart';
import 'NewExpense.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  );
  bool _isLoading = true;
  List<Map<String, dynamic>> _expenses = [];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Get expenses from user's personal expense history
      final expensesQuery =
          await _firestore
              .collection('userExpenses')
              .doc(currentUser.uid)
              .collection('expenses')
              .orderBy('timestamp', descending: true)
              .get();

      // Get the full expense details for each expense
      final List<Map<String, dynamic>> expenses = [];

      for (var doc in expensesQuery.docs) {
        try {
          final expenseData = doc.data();
          final expenseId = expenseData['expenseId'];

          // Get the full expense details
          final expenseDoc =
              await _firestore.collection('expenses').doc(expenseId).get();

          if (expenseDoc.exists) {
            final fullExpenseData = expenseDoc.data()!;
            expenses.add({'id': expenseId, ...expenseData, ...fullExpenseData});
          } else {
            // Fallback to basic data if full expense not found
            expenses.add({'id': expenseId, ...expenseData});
          }
        } catch (e) {
          debugPrint('Error loading expense details: $e');
        }
      }

      if (mounted) {
        setState(() {
          _expenses = expenses;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading expenses: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load expense history')),
        );
      }
    }
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    final currentUser = _auth.currentUser;
    final bool isPayer = expense['payerId'] == currentUser?.uid;
    final bool isYou = isPayer;
    final String description = expense['description'] ?? 'Expense';
    final double amount = (expense['amount'] ?? 0).toDouble();
    final String payerName = expense['payerName'] ?? 'Someone';
    final DateTime? timestamp = expense['timestamp']?.toDate();

    // Get current user's share
    double userShare = 0;
    if (expense['shares'] != null && currentUser != null) {
      final shares = Map<String, dynamic>.from(expense['shares']);
      userShare = (shares[currentUser.uid] ?? 0).toDouble();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: isPayer ? Colors.green[100] : Colors.blue[100],
          child: Icon(
            isYou ? Icons.person : Icons.person_outline,
            color: isPayer ? Colors.green : Colors.blue,
          ),
        ),
        title: Text(
          description,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              isYou
                  ? 'You paid ${_currencyFormat.format(amount)}'
                  : '$payerName paid ${_currencyFormat.format(amount)}',
              style: const TextStyle(fontSize: 14),
            ),
            if (!isYou)
              Text(
                'Your share: ${_currencyFormat.format(userShare)}',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (timestamp != null)
              Text(
                _formatDate(timestamp),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
          ],
        ),
        trailing: Icon(
          isPayer ? Icons.arrow_upward : Icons.arrow_downward,
          color: isPayer ? Colors.green : Colors.blue,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF3E0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(40, 40, 40, 20),
              child: Text(
                "Expense Activity",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search expenses",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (value) {
                  // TODO: Implement search functionality
                },
              ),
            ),

            // Expense List
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _expenses.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                        onRefresh: _loadExpenses,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(top: 10, bottom: 20),
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            return _buildExpenseCard(_expenses[index]);
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.monetization_on, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            const Text(
              "No expenses yet!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "When you add or split expenses with friends,\nthey'll appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NewExpenseScreen(),
                  ),
                ).then((_) => _loadExpenses());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Add an expense",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
