import 'package:flutter/material.dart';
import '../widgets/custom_bottom_nav.dart';

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
  final TextEditingController totalAmountController = TextEditingController();
  bool isCustomSplit = false;
  String? selectedPayer;

  @override
  void initState() {
    super.initState();
    members =
        widget.selectedFriends
            .map(
              (friend) => {
                "name": friend["username"],
                "selected": true,
                "amount": 0.0,
                "controller": TextEditingController(),
              },
            )
            .toList();
    if (members.isNotEmpty) {
      selectedPayer =
          members.first["name"]; // Automatically select the first payer
    }
  }

  void splitAmount() {
    double totalAmount = double.tryParse(totalAmountController.text) ?? 0;
    int selectedCount = members.where((m) => m["selected"]).length;
    if (selectedCount > 0 && !isCustomSplit) {
      double splitAmount = totalAmount / selectedCount;
      setState(() {
        for (var member in members) {
          if (member["selected"]) {
            member["amount"] = splitAmount;
            member["controller"].text = splitAmount.toStringAsFixed(2);
          } else {
            member["amount"] = 0;
            member["controller"].clear();
          }
        }
      });
    }
  }

  void validateCustomSplit() {
    double totalAmount = double.tryParse(totalAmountController.text) ?? 0;
    double enteredTotal = members.fold(0, (sum, member) {
      return sum + (double.tryParse(member["controller"].text) ?? 0);
    });

    if (enteredTotal != totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Total must be ₹${totalAmount.toStringAsFixed(2)}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAF3E0),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.shade100,
                  ),
                  onPressed: () {},
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                  ),
                  onPressed: validateCustomSplit,
                  child: const Text(
                    "Save Expense",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
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
                                      decoration: InputDecoration(
                                        hintText: "Add a new expense",
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
                                        hintText: "Amount",
                                        border: InputBorder.none,
                                      ),
                                      onChanged: (value) => splitAmount(),
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
                                children: [
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
                                              members.map((member) {
                                                return DropdownMenuItem<String>(
                                                  value: member["name"],
                                                  child: Text(member["name"]!),
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
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),

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
            Expanded(
              child: ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  var member = members[index];
                  return ListTile(
                    title: Text(member["name"]),
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
                                  color:
                                      Colors.transparent, // No background color
                                  borderRadius: BorderRadius.circular(
                                    20,
                                  ), // Rounded corners
                                  border: Border.all(
                                    color: Colors.grey,
                                    width: 0.5,
                                  ), // Gray border
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

                                      // Get selected members except the one being modified
                                      List<Map<String, dynamic>>
                                      selectedMembers =
                                          members
                                              .where((m) => m["selected"])
                                              .toList();

                                      int remainingMembers =
                                          selectedMembers.length - 1;

                                      if (remainingMembers > 0) {
                                        // Calculate remaining amount to distribute
                                        double remainingAmount =
                                            totalAmount - enteredAmount;

                                        if (remainingAmount >= 0) {
                                          double splitAmount =
                                              remainingAmount /
                                              remainingMembers;

                                          for (var m in selectedMembers) {
                                            if (m != member) {
                                              m["amount"] = splitAmount;
                                              m["controller"].text = splitAmount
                                                  .toStringAsFixed(2);
                                            }
                                          }
                                          member["amount"] = enteredAmount;
                                        } else {
                                          // Prevent entering more than total
                                          member["controller"]
                                              .text = member["amount"]
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
