import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatelessWidget {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Add refresh functionality if needed
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(context),
              SizedBox(height: 24),
              _buildQuickStats(),
              SizedBox(height: 24),
              _buildLowStockAlert(),
              SizedBox(height: 24),
              _buildExpiryAlert(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavButton(
                context,
                icon: Icons.dashboard,
                label: 'Dashboard',
                isSelected: true,
                onTap: () {},
              ),
              _buildNavButton(
                context,
                icon: Icons.inventory,
                label: 'Inventory',
                isSelected: false,
                onTap: () => Navigator.pushNamed(context, '/inventory'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to MediTrack',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 8),
            Text(
              'Manage your medical inventory efficiently',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/inventory'),
              icon: Icon(Icons.add),
              label: Text('Add Medicine'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getMedicines(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        int totalItems = snapshot.data!.docs.length;
        int lowStock = 0;
        int expiringSoon = 0;

        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['stock'] < 10) lowStock++;
          
          try {
            DateTime expiryDate = DateFormat('yyyy-MM-dd').parse(data['expiry_date']);
            if (expiryDate.difference(DateTime.now()).inDays < 30) {
              expiringSoon++;
            }
          } catch (e) {
            // Handle invalid date format
          }
        }

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Total Items',
                totalItems.toString(),
                Icons.medication,
                Colors.blue,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context,
                'Low Stock',
                lowStock.toString(),
                Icons.warning,
                Colors.orange,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context,
                'Expiring Soon',
                expiringSoon.toString(),
                Icons.timer,
                Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockAlert() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getMedicines(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox();

        var lowStockItems = snapshot.data!.docs
            .where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return data['stock'] < 10;
            })
            .take(3)
            .toList();

        if (lowStockItems.isEmpty) return SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Low Stock Alert',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: 8),
            ...lowStockItems.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: Icon(Icons.warning, color: Colors.orange),
                  title: Text(data['name']),
                  subtitle: Text('Current stock: ${data['stock']}'),
                  trailing: TextButton(
                    child: Text('View'),
                    onPressed: () => Navigator.pushNamed(context, '/inventory'),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildExpiryAlert() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getMedicines(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox();

        var expiringItems = snapshot.data!.docs
            .where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              try {
                DateTime expiryDate =
                    DateFormat('yyyy-MM-dd').parse(data['expiry_date']);
                return expiryDate.difference(DateTime.now()).inDays < 30;
              } catch (e) {
                return false;
              }
            })
            .take(3)
            .toList();

        if (expiringItems.isEmpty) return SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expiring Soon',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 8),
            ...expiringItems.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: Icon(Icons.timer, color: Colors.red),
                  title: Text(data['name']),
                  subtitle: Text('Expires: ${data['expiry_date']}'),
                  trailing: TextButton(
                    child: Text('View'),
                    onPressed: () => Navigator.pushNamed(context, '/inventory'),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildNavButton(BuildContext context,
      {required IconData icon,
      required String label,
      required bool isSelected,
      required VoidCallback onTap}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey[600],
                ),
                SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
