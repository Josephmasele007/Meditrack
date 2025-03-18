import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user's medicines collection reference
  CollectionReference _getMedicinesRef() {
    return _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('medicines');
  }

  // Get stream of medicines
  Stream<QuerySnapshot> getMedicines() {
    return _getMedicinesRef().snapshots();
  }

  // Add a medicine
  Future<void> addMedicine(String name, int stock, String expiryDate,
      double price, String description) async {
    await _getMedicinesRef().add({
      'name': name,
      'stock': stock,
      'expiry_date': expiryDate,
      'price': price,
      'description': description,
      'min_stock': 10, // Default minimum stock level
      'stock_history': [
        {
          'stock': stock,
          'timestamp': FieldValue.serverTimestamp(),
          'action': 'initial',
        }
      ],
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Update a medicine
  Future<void> updateMedicine(String id, Map<String, dynamic> data) async {
    final docRef = _getMedicinesRef().doc(id);
    final currentDoc = await docRef.get();
    final currentData = currentDoc.data() as Map<String, dynamic>;

    // If stock is being updated, add to history
    if (data.containsKey('stock') && data['stock'] != currentData['stock']) {
      List<dynamic> history = List.from(currentData['stock_history'] ?? []);
      history.add({
        'stock': data['stock'],
        'timestamp': FieldValue.serverTimestamp(),
        'action': 'update',
      });
      data['stock_history'] = history;
    }

    data['updated_at'] = FieldValue.serverTimestamp();
    await docRef.update(data);
  }

  // Delete a medicine
  Future<void> deleteMedicine(String id) async {
    await _getMedicinesRef().doc(id).delete();
  }

  // Get low stock medicines
  Stream<QuerySnapshot> getLowStockMedicines(int threshold) {
    return _getMedicinesRef()
        .where('stock', isLessThan: threshold)
        .snapshots();
  }

  // Get medicines expiring soon
  Stream<QuerySnapshot> getExpiringMedicines(DateTime before) {
    String dateString = before.toIso8601String().split('T')[0];
    return _getMedicinesRef()
        .where('expiry_date', isLessThanOrEqualTo: dateString)
        .snapshots();
  }

  // Update stock
  Future<void> updateStock(String id, int newStock, {String action = 'update'}) async {
    final docRef = _getMedicinesRef().doc(id);
    final doc = await docRef.get();
    final data = doc.data() as Map<String, dynamic>;
    
    List<dynamic> history = List.from(data['stock_history'] ?? []);
    history.add({
      'stock': newStock,
      'timestamp': FieldValue.serverTimestamp(),
      'action': action,
    });

    await docRef.update({
      'stock': newStock,
      'stock_history': history,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Batch update stocks
  Future<void> batchUpdateStocks(Map<String, int> updates) async {
    final batch = _firestore.batch();
    
    for (var entry in updates.entries) {
      final docRef = _getMedicinesRef().doc(entry.key);
      final doc = await docRef.get();
      final data = doc.data() as Map<String, dynamic>;
      
      List<dynamic> history = List.from(data['stock_history'] ?? []);
      history.add({
        'stock': entry.value,
        'timestamp': FieldValue.serverTimestamp(),
        'action': 'batch_update',
      });

      batch.update(docRef, {
        'stock': entry.value,
        'stock_history': history,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Get medicine by ID
  Future<DocumentSnapshot> getMedicineById(String id) {
    return _getMedicinesRef().doc(id).get();
  }

  // Search medicines by name
  Stream<QuerySnapshot> searchMedicines(String query) {
    return _getMedicinesRef()
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: query + '\uf8ff')
        .snapshots();
  }

  // Update minimum stock level
  Future<void> updateMinStock(String id, int minStock) async {
    await _getMedicinesRef().doc(id).update({
      'min_stock': minStock,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Get stock history for a medicine
  Future<List<Map<String, dynamic>>> getStockHistory(String id) async {
    final doc = await _getMedicinesRef().doc(id).get();
    final data = doc.data() as Map<String, dynamic>;
    final history = data['stock_history'] ?? [];
    return List<Map<String, dynamic>>.from(history);
  }

  // Get stock changes between dates
  Future<List<Map<String, dynamic>>> getStockChangesBetweenDates(
    String id,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final doc = await _getMedicinesRef().doc(id).get();
    final data = doc.data() as Map<String, dynamic>;
    final history = List<Map<String, dynamic>>.from(data['stock_history'] ?? []);

    return history.where((entry) {
      final timestamp = (entry['timestamp'] as Timestamp).toDate();
      return timestamp.isAfter(startDate) && timestamp.isBefore(endDate);
    }).toList();
  }
}
