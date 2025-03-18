import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ml_algo/ml_algo.dart';
import 'package:ml_dataframe/ml_dataframe.dart';
import 'package:ml_preprocessing/ml_preprocessing.dart';
import 'package:stats/stats.dart';
import '../services/firestore_service.dart';

class AnalyticsService {
  final FirestoreService _firestoreService = FirestoreService();

  // Predict stock levels for the next n days
  Future<Map<String, dynamic>> predictStockLevels(String medicineId, int days) async {
    try {
      // Get historical data
      final snapshot = await _firestoreService.getMedicineById(medicineId);
      final data = snapshot.data() as Map<String, dynamic>;
      final stockHistory = data['stock_history'] ?? [];

      if (stockHistory.length < 7) {
        return {
          'error': 'Insufficient data for prediction',
          'recommendation': 'Continue tracking stock for at least 7 days',
        };
      }

      // Convert history to DataFrame format
      final List<Map<String, num>> numericalData = stockHistory.map<Map<String, num>>((entry) {
        return {
          'day': entry['timestamp'].toDate().millisecondsSinceEpoch,
          'stock': entry['stock'].toDouble(),
        };
      }).toList();

      final df = DataFrame(numericalData);
      
      // Train linear regression model
      final model = LinearRegressor(
        df,
        'stock',
        fitIntercept: true,
        interceptScale: 1.0,
      );

      // Make predictions
      final lastDay = DateTime.now().add(Duration(days: days));
      final prediction = model.predict(DataFrame([
        {'day': lastDay.millisecondsSinceEpoch}
      ]));

      return {
        'current_stock': data['stock'],
        'predicted_stock': prediction[0],
        'days_until_empty': _calculateDaysUntilEmpty(data['stock'], stockHistory),
        'recommendation': _generateRecommendation(
          data['stock'],
          prediction[0],
          data['min_stock'] ?? 10,
        ),
      };
    } catch (e) {
      return {
        'error': 'Error predicting stock levels',
        'details': e.toString(),
      };
    }
  }

  // Analyze demand patterns
  Future<Map<String, dynamic>> analyzeDemandPatterns(String medicineId) async {
    try {
      final snapshot = await _firestoreService.getMedicineById(medicineId);
      final data = snapshot.data() as Map<String, dynamic>;
      final stockHistory = data['stock_history'] ?? [];

      if (stockHistory.isEmpty) {
        return {
          'error': 'No historical data available',
          'recommendation': 'Start tracking stock changes to analyze demand',
        };
      }

      // Calculate daily demand
      List<num> dailyDemand = [];
      for (int i = 1; i < stockHistory.length; i++) {
        final prev = stockHistory[i - 1];
        final curr = stockHistory[i];
        final demand = prev['stock'] - curr['stock'];
        if (demand > 0) dailyDemand.add(demand);
      }

      if (dailyDemand.isEmpty) {
        return {
          'error': 'No demand patterns detected',
          'recommendation': 'Continue tracking stock changes',
        };
      }

      // Calculate statistics
      final stats = Stats.fromData(dailyDemand);
      final weekdayDemand = _analyzeWeekdayDemand(stockHistory);

      return {
        'average_daily_demand': stats.average.toStringAsFixed(1),
        'peak_daily_demand': stats.max.toStringAsFixed(1),
        'demand_variability': stats.standardDeviation.toStringAsFixed(2),
        'weekday_patterns': weekdayDemand,
        'recommendation': _generateDemandRecommendation(
          stats.average,
          stats.standardDeviation,
          weekdayDemand,
        ),
      };
    } catch (e) {
      return {
        'error': 'Error analyzing demand patterns',
        'details': e.toString(),
      };
    }
  }

  // Get low stock alerts with AI-driven insights
  Future<List<Map<String, dynamic>>> getLowStockInsights() async {
    try {
      final medicines = await _firestoreService.getMedicines().first;
      List<Map<String, dynamic>> insights = [];

      for (var doc in medicines.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final stockPrediction = await predictStockLevels(doc.id, 7);
        final demandAnalysis = await analyzeDemandPatterns(doc.id);

        if (data['stock'] < (data['min_stock'] ?? 10) ||
            (stockPrediction['predicted_stock'] ?? double.infinity) < (data['min_stock'] ?? 10)) {
          insights.add({
            'id': doc.id,
            'name': data['name'],
            'current_stock': data['stock'],
            'min_stock': data['min_stock'] ?? 10,
            'predicted_stock': stockPrediction['predicted_stock'],
            'days_until_empty': stockPrediction['days_until_empty'],
            'average_daily_demand': demandAnalysis['average_daily_demand'],
            'recommendation': _combineRecommendations(
              stockPrediction['recommendation'],
              demandAnalysis['recommendation'],
            ),
            'urgency_level': _calculateUrgencyLevel(
              data['stock'],
              data['min_stock'] ?? 10,
              stockPrediction['predicted_stock'],
            ),
          });
        }
      }

      return insights;
    } catch (e) {
      return [{
        'error': 'Error generating low stock insights',
        'details': e.toString(),
      }];
    }
  }

  // Calculate days until stock is empty based on historical data
  int _calculateDaysUntilEmpty(int currentStock, List<dynamic> history) {
    if (history.isEmpty || currentStock <= 0) return 0;

    // Calculate average daily consumption
    double totalConsumption = 0;
    int days = 0;
    for (int i = 1; i < history.length; i++) {
      final prev = history[i - 1]['stock'];
      final curr = history[i]['stock'];
      if (prev > curr) {
        totalConsumption += (prev - curr);
        days++;
      }
    }

    if (days == 0) return 30; // Default if no consumption pattern
    double avgDailyConsumption = totalConsumption / days;
    return avgDailyConsumption > 0
        ? (currentStock / avgDailyConsumption).round()
        : 30;
  }

  // Analyze demand patterns by weekday
  Map<String, double> _analyzeWeekdayDemand(List<dynamic> history) {
    Map<String, List<double>> weekdayDemand = {
      'Monday': [],
      'Tuesday': [],
      'Wednesday': [],
      'Thursday': [],
      'Friday': [],
      'Saturday': [],
      'Sunday': [],
    };

    for (int i = 1; i < history.length; i++) {
      final prev = history[i - 1];
      final curr = history[i];
      final demand = prev['stock'] - curr['stock'];
      if (demand > 0) {
        final date = (curr['timestamp'] as Timestamp).toDate();
        final weekday = DateFormat('EEEE').format(date);
        weekdayDemand[weekday]!.add(demand.toDouble());
      }
    }

    return weekdayDemand.map((key, value) {
      if (value.isEmpty) return MapEntry(key, 0.0);
      return MapEntry(key, value.reduce((a, b) => a + b) / value.length);
    });
  }

  // Generate stock-based recommendation
  String _generateRecommendation(int currentStock, double predictedStock, int minStock) {
    if (currentStock <= minStock) {
      return 'Immediate restock required. Current stock below minimum threshold.';
    } else if (predictedStock <= minStock) {
      return 'Consider restocking soon. Stock predicted to fall below minimum threshold.';
    } else if (currentStock <= minStock * 2) {
      return 'Monitor stock levels closely. Current stock approaching minimum threshold.';
    }
    return 'Stock levels adequate. Continue regular monitoring.';
  }

  // Generate demand-based recommendation
  String _generateDemandRecommendation(
    double avgDemand,
    double stdDev,
    Map<String, double> weekdayDemand,
  ) {
    final highDemandDays = weekdayDemand.entries
        .where((e) => e.value > avgDemand + stdDev)
        .map((e) => e.key)
        .toList();

    if (highDemandDays.isNotEmpty) {
      return 'Higher demand observed on ${highDemandDays.join(", ")}. Consider increasing stock before these days.';
    } else if (stdDev > avgDemand) {
      return 'Highly variable demand pattern. Maintain higher safety stock.';
    } else if (stdDev < avgDemand / 2) {
      return 'Stable demand pattern. Standard safety stock adequate.';
    }
    return 'Moderate demand variability. Monitor trends regularly.';
  }

  // Combine multiple recommendations
  String _combineRecommendations(String stockRec, String demandRec) {
    if (stockRec.contains('Immediate') || stockRec.contains('Consider restocking')) {
      return '$stockRec $demandRec';
    }
    return stockRec;
  }

  // Calculate urgency level (1-5, 5 being most urgent)
  int _calculateUrgencyLevel(int currentStock, int minStock, double? predictedStock) {
    if (currentStock <= 0) return 5;
    if (currentStock <= minStock / 2) return 4;
    if (currentStock <= minStock) return 3;
    if (predictedStock != null && predictedStock <= minStock) return 2;
    return 1;
  }
}
