// lib/models/transaction.dart

import 'package:intl/intl.dart';

enum TransactionType { purchase, dividend }

class Transaction {
  int? id;
  String assetName; // Nombre de la acción/FII
  TransactionType type; // Compra o Provento
  double price; // Precio unitario (en compra) o monto (en provento)
  double quantity; // Cantidad de acciones/cuotas
  double totalValue; // Valor total (precio * cantidad)
  DateTime date;

  Transaction({
    this.id,
    required this.assetName,
    required this.type,
    required this.price,
    required this.quantity,
    required this.totalValue,
    required this.date,
  });

  // Método para convertir un Objeto en un Map (para SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'assetName': assetName,
      'type':
          type.index, // Almacenamos el índice del enum (0=purchase, 1=dividend)
      'price': price,
      'quantity': quantity,
      'totalValue': totalValue,
      'date': DateFormat('yyyy-MM-dd HH:mm:ss').format(date),
    };
  }

  // Método estático para crear un Objeto a partir de un Map (desde SQLite)
  static Transaction fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      assetName: map['assetName'],
      type: TransactionType.values[map['type']],
      price: map['price'],
      quantity: map['quantity'],
      totalValue: map['totalValue'],
      date: DateTime.parse(map['date']),
    );
  }
}
