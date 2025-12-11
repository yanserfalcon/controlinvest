// lib/utils/calculations.dart

// CORREGIDO: Añadir la importación de intl para DateFormat
import 'package:intl/intl.dart';
import '../models/transaction.dart' as model; // Añadir prefijo

// Clase para contener el resumen de un activo
class AssetSummary {
  double investedValue = 0.0;
  double quantity = 0.0;
  double totalDividends = 0.0;

  // Valor actual (Cantidad * Precio Medio) - Es el valor invertido para esta app
  double get currentValue => investedValue;

  // Precio Medio (Invertido / Cantidad)
  double get averagePrice => quantity > 0 ? investedValue / quantity : 0.0;
}

// Función principal de cálculo del Dashboard
// CORREGIDO: Usar model.Transaction
Map<String, AssetSummary> calculateAssetSummary(
  List<model.Transaction> transactions,
) {
  final Map<String, AssetSummary> summaries = {};

  // 1. Calcular el total invertido y la cantidad para cada activo (sólo COMPRAS)
  for (final tx in transactions) {
    final assetName = tx.assetName.toUpperCase();
    if (!summaries.containsKey(assetName)) {
      summaries[assetName] = AssetSummary();
    }

    // CORREGIDO: Usar model.TransactionType.purchase
    if (tx.type == model.TransactionType.purchase) {
      // Se suman los valores invertidos y las cantidades
      summaries[assetName]!.investedValue += tx.totalValue;
      summaries[assetName]!.quantity += tx.quantity;
    }
  }

  // 2. Eliminar activos con cantidad cero (vendidos completamente) y calcular el precio medio final
  final List<String> assetsToRemove = [];
  summaries.forEach((key, summary) {
    if (summary.quantity <= 0) {
      assetsToRemove.add(key);
    }
  });

  for (final asset in assetsToRemove) {
    summaries.remove(asset);
  }

  // 3. Calcular el total de proventos
  for (final tx in transactions) {
    final assetName = tx.assetName.toUpperCase();
    // CORREGIDO: Usar model.TransactionType.dividend
    if (tx.type == model.TransactionType.dividend &&
        summaries.containsKey(assetName)) {
      summaries[assetName]!.totalDividends += tx.totalValue;
    }
  }

  return summaries;
}

// Calcula los proventos por mes para un año específico
// CORREGIDO: Usar model.Transaction
Map<String, double> calculateMonthlyDividends(
  List<model.Transaction> transactions,
  int year,
) {
  final Map<int, double> monthlyData = {for (var i = 1; i <= 12; i++) i: 0.0};

  for (final tx in transactions) {
    // CORREGIDO: Usar model.TransactionType.dividend
    if (tx.type == model.TransactionType.dividend && tx.date.year == year) {
      final month = tx.date.month;
      monthlyData[month] = monthlyData[month]! + tx.totalValue;
    }
  }

  // Convertir el mapa de meses a nombres de meses
  final Map<String, double> result = {};
  for (final entry in monthlyData.entries) {
    final monthName = DateFormat('MMM').format(DateTime(year, entry.key));
    result[monthName] = entry.value;
  }
  return result;
}

// Calcula los proventos por año
// CORREGIDO: Usar model.Transaction
Map<String, double> calculateYearlyDividends(
  List<model.Transaction> transactions,
) {
  final Map<int, double> yearlyData = {};

  for (final tx in transactions) {
    // CORREGIDO: Usar model.TransactionType.dividend
    if (tx.type == model.TransactionType.dividend) {
      final year = tx.date.year;
      yearlyData[year] = (yearlyData[year] ?? 0.0) + tx.totalValue;
    }
  }

  // Ordenar por año y convertir a String
  final Map<String, double> result = {};
  final sortedKeys = yearlyData.keys.toList()..sort();
  for (final year in sortedKeys) {
    result[year.toString()] = yearlyData[year]!;
  }
  return result;
}
