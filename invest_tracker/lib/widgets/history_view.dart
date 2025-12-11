// lib/widgets/history_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// CORREGIDO: Usar el prefijo 'model'
import '../models/transaction.dart' as model;

class HistoryView extends StatelessWidget {
  // CORREGIDO: Usar model.Transaction
  final List<model.Transaction> transactions;
  // CORREGIDO: Usar model.Transaction
  final Function(model.Transaction) onEdit;
  final Function(int) onDelete;

  const HistoryView({
    super.key,
    required this.transactions,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_ES', symbol: '\$');

    if (transactions.isEmpty) {
      return const Center(child: Text('No hay transacciones en el historial.'));
    }

    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        // CORREGIDO: Usar model.TransactionType
        final isPurchase = tx.type == model.TransactionType.purchase;
        final icon = isPurchase ? Icons.shopping_cart : Icons.attach_money;
        final color = isPurchase ? Colors.blue[700] : Colors.green[700];

        return Dismissible(
          key: Key(tx.id.toString()),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text("Confirmar Eliminación"),
                  content: Text(
                    "¿Estás seguro de que quieres eliminar la transacción de ${tx.assetName}?",
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text("Cancelar"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text("Eliminar"),
                    ),
                  ],
                );
              },
            );
          },
          onDismissed: (direction) {
            onDelete(tx.id!);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${tx.assetName} eliminado.')),
            );
          },
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: ListTile(
            leading: Icon(icon, color: color),
            title: Text(
              '${isPurchase ? 'Compra' : 'Provento'} de ${tx.assetName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${DateFormat('yyyy-MM-dd').format(tx.date)} - '
              'Valor Total: ${currencyFormat.format(tx.totalValue)}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit, color: Colors.grey),
              onPressed: () => onEdit(tx),
            ),
          ),
        );
      },
    );
  }
}
