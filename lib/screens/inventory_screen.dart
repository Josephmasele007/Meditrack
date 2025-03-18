import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';

class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController expiryController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    nameController.dispose();
    stockController.dispose();
    expiryController.dispose();
    priceController.dispose();
    descController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _clearControllers() {
    nameController.clear();
    stockController.clear();
    expiryController.clear();
    priceController.clear();
    descController.clear();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      expiryController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> addMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _firestoreService.addMedicine(
        nameController.text.trim(),
        int.parse(stockController.text.trim()),
        expiryController.text.trim(),
        double.parse(priceController.text.trim()),
        descController.text.trim(),
      );
      Navigator.pop(context);
      _clearControllers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Medicine added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding medicine: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDelete(String id, String medicineName) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Medicine'),
        content: Text('Are you sure you want to delete $medicineName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                Navigator.pop(context);
                await _firestoreService.deleteMedicine(id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Medicine deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting medicine'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void showAddMedicineDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add Medicine"),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null)
                  Container(
                    padding: EdgeInsets.all(8),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Name *",
                    prefixIcon: Icon(Icons.medication),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter medicine name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: stockController,
                  decoration: InputDecoration(
                    labelText: "Stock *",
                    prefixIcon: Icon(Icons.inventory),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter stock quantity';
                    }
                    try {
                      int stock = int.parse(value);
                      if (stock < 0) {
                        return 'Stock cannot be negative';
                      }
                    } catch (e) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: expiryController,
                      decoration: InputDecoration(
                        labelText: "Expiry Date * (YYYY-MM-DD)",
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please select expiry date';
                        }
                        try {
                          DateFormat('yyyy-MM-dd').parse(value);
                        } catch (e) {
                          return 'Invalid date format';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText: "Price *",
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter price';
                    }
                    try {
                      double price = double.parse(value);
                      if (price < 0) {
                        return 'Price cannot be negative';
                      }
                    } catch (e) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: "Description (Optional)",
                    prefixIcon: Icon(Icons.description),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _clearControllers();
              Navigator.pop(context);
            },
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : addMedicine,
            child: _isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Inventory"),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search medicines...",
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                // Implement search functionality
                setState(() {});
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getMedicines(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var medicines = snapshot.data!.docs;
          
          // Filter medicines based on search
          if (searchController.text.isNotEmpty) {
            medicines = medicines.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return data['name']
                  .toString()
                  .toLowerCase()
                  .contains(searchController.text.toLowerCase());
            }).toList();
          }

          if (medicines.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    searchController.text.isEmpty
                        ? 'No medicines in inventory'
                        : 'No medicines found',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: medicines.length,
            itemBuilder: (context, index) {
              var data = medicines[index].data() as Map<String, dynamic>;
              var id = medicines[index].id;
              var isLowStock = data['stock'] < 10;
              var isExpiringSoon = false;

              try {
                var expiryDate = DateFormat('yyyy-MM-dd').parse(data['expiry_date']);
                isExpiringSoon =
                    expiryDate.difference(DateTime.now()).inDays < 30;
              } catch (e) {
                // Handle invalid date format
              }

              return Card(
                child: ListTile(
                  title: Text(
                    data['name'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.inventory, size: 16, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            'Stock: ${data['stock']}',
                            style: TextStyle(
                              color: isLowStock ? Colors.orange : null,
                            ),
                          ),
                          SizedBox(width: 16),
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            'Expires: ${data['expiry_date']}',
                            style: TextStyle(
                              color: isExpiringSoon ? Colors.red : null,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.attach_money, size: 16, color: Colors.grey),
                          SizedBox(width: 4),
                          Text('\$${data['price'].toStringAsFixed(2)}'),
                        ],
                      ),
                      if (data['description']?.isNotEmpty ?? false) ...[
                        SizedBox(height: 4),
                        Text(
                          data['description'],
                          style: TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(id, data['name']),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddMedicineDialog,
        child: Icon(Icons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pushReplacementNamed(context, '/dashboard'),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.dashboard, color: Colors.grey[600]),
                          SizedBox(height: 4),
                          Text(
                            'Dashboard',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory,
                            color: Theme.of(context).primaryColor,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Inventory',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
