// lib/widgets/history_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart' as model;

class HistoryView extends StatefulWidget {
  final List<model.Transaction> transactions;
  final Function(model.Transaction) onEdit;
  final Function(int) onDelete;
  // Campos para filtros iniciales (deep link)
  final model.TransactionType? initialFilterType;
  final DateTime? initialFilterDate;

  const HistoryView({
    super.key,
    required this.transactions,
    required this.onEdit,
    required this.onDelete,
    this.initialFilterType,
    this.initialFilterDate,
  });

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  // Filtros de estado interno
  String _typeFilter = 'all'; // 'all', 'purchase', 'dividend'
  String _assetFilter = 'all'; // 'all' o un ticker específico
  String _periodFilter = 'all'; // 'all', 'month', 'year'
  DateTime? _selectedDate; // Fecha de filtro para mes o año

  @override
  void initState() {
    super.initState();
    _applyInitialFilters();
    // Inicializar intl con la localización si es necesario (ya está en main.dart generalmente)
    Intl.defaultLocale = 'es_ES';
  }

  @override
  void didUpdateWidget(covariant HistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Vuelve a aplicar filtros si los filtros iniciales de MainScreen cambian
    if (widget.initialFilterType != oldWidget.initialFilterType ||
        widget.initialFilterDate != oldWidget.initialFilterDate) {
      _applyInitialFilters();
    }
  }

  void _applyInitialFilters() {
    setState(() {
      // Reiniciar filtros manuales antes de aplicar los del deep-link
      _typeFilter = 'all';
      _assetFilter = 'all';
      _selectedDate = null;
      _periodFilter = 'all';

      // Aplicar filtro de tipo
      if (widget.initialFilterType == model.TransactionType.purchase) {
        _typeFilter = 'purchase';
      } else if (widget.initialFilterType == model.TransactionType.dividend) {
        _typeFilter = 'dividend';
      }

      // Aplicar filtro de fecha (desde Dashboard)
      if (widget.initialFilterDate != null) {
        final date = widget.initialFilterDate!;
        _selectedDate = date;
        // La clave de fecha 'YYYY-MM' (mes) o 'YYYY' (año) determina el filtro.
        if (date.month == 1 && date.day == 1) {
          _periodFilter = 'year';
        } else {
          _periodFilter = 'month';
        }
      }
    });
  }

  // Lista de Assets únicos para el filtro
  List<String> get uniqueAssets {
    final assets = widget.transactions.map((t) => t.assetName).toSet().toList();
    assets.sort();
    return ['all', ...assets];
  }

  // Lógica de filtrado principal
  List<model.Transaction> get _filteredTransactions {
    List<model.Transaction> filtered = widget.transactions;

    // 1. Filtrar por Tipo
    if (_typeFilter != 'all') {
      final targetType = _typeFilter == 'purchase'
          ? model.TransactionType.purchase
          : model.TransactionType.dividend;
      filtered = filtered.where((tx) => tx.type == targetType).toList();
    }

    // 2. Filtrar por Activo
    if (_assetFilter != 'all') {
      filtered = filtered.where((tx) => tx.assetName == _assetFilter).toList();
    }

    // 3. Filtrar por Periodo (Mes/Año)
    if (_periodFilter != 'all' && _selectedDate != null) {
      final targetDate = _selectedDate!;

      if (_periodFilter == 'month') {
        filtered = filtered
            .where(
              (tx) =>
                  tx.date.year == targetDate.year &&
                  tx.date.month == targetDate.month,
            )
            .toList();
      } else if (_periodFilter == 'year') {
        filtered = filtered
            .where((tx) => tx.date.year == targetDate.year)
            .toList();
      }
    }

    // Ordenar por fecha descendente
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  // Función para seleccionar el periodo (Solo el año para simplificar la UX de filtro)
  Future<void> _selectYear(BuildContext context) async {
    final List<int> years =
        widget.transactions.map((t) => t.date.year).toSet().toList()
          ..sort((a, b) => b.compareTo(a));

    if (years.isEmpty) return;

    final selectedYear = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Seleccionar Año"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: years
                  .map(
                    (year) => ListTile(
                      title: Text(year.toString()),
                      onTap: () => Navigator.of(context).pop(year),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );

    if (selectedYear != null) {
      setState(() {
        // Usamos el 1 de enero de ese año como clave para el filtro de año
        _selectedDate = DateTime(selectedYear);
        _periodFilter = 'year';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // final currencyFormat = NumberFormat.currency(locale: 'es_ES', symbol: '\$');
    final currencyFormat = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    final filteredTransactions = _filteredTransactions;

    // --- Selectores de Filtro ---
    final filterWidgets = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        children: <Widget>[
          // Filtro por TIPO (Compra / Provento)
          DropdownButton<String>(
            value: _typeFilter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Todo Tipo')),
              DropdownMenuItem(value: 'purchase', child: Text('Compra')),
              DropdownMenuItem(value: 'dividend', child: Text('Provento')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _typeFilter = value;
                });
              }
            },
          ),

          // Filtro por ACTIVO (Ticker)
          DropdownButton<String>(
            value: _assetFilter,
            items: uniqueAssets.map((asset) {
              return DropdownMenuItem(
                value: asset,
                child: Text(asset == 'all' ? 'Todo Activo' : asset),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _assetFilter = value;
                });
              }
            },
          ),

          // Filtro por PERIODO (Mes / Año / Todo)
          DropdownButton<String>(
            value: _periodFilter,
            // Lista de items construida dinámicamente para incluir 'month' si está activo
            items: [
              const DropdownMenuItem(value: 'all', child: Text('Todo Periodo')),
              const DropdownMenuItem(value: 'year', child: Text('Por Año')),
              // Incluir 'month' solo si es el valor seleccionado (debido al deep-link)
              if (_periodFilter == 'month')
                const DropdownMenuItem(value: 'month', child: Text('Por Mes')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _periodFilter = value;
                  _selectedDate = null; // Reiniciar fecha al cambiar modo
                  if (value == 'year') {
                    _selectYear(context);
                  } else if (value == 'all') {
                    _selectedDate = null;
                  }
                });
              }
            },
          ),

          // Muestra el periodo seleccionado actualmente (Chip)
          if (_periodFilter != 'all' && _selectedDate != null)
            InputChip(
              // <-- CORRECCIÓN: Uso de InputChip para onDeleted
              label: Text(
                _periodFilter == 'month'
                    ? DateFormat('MMMM yyyy', 'es_ES').format(_selectedDate!)
                    : DateFormat('yyyy', 'es_ES').format(_selectedDate!),
              ),
              onPressed: () {
                // Si se toca, permite cambiar el año, a menos que ya sea por mes (deep link)
                if (_periodFilter != 'month') {
                  _selectYear(context);
                }
              },
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () {
                setState(() {
                  _selectedDate = null;
                  _periodFilter = 'all';
                });
              },
            ),
        ],
      ),
    );

    // --- Contenido de la vista ---
    if (widget.transactions.isEmpty) {
      return const Center(child: Text('No hay transacciones en el historial.'));
    }

    if (filteredTransactions.isEmpty && widget.transactions.isNotEmpty) {
      return Column(
        children: [
          filterWidgets,
          const Expanded(
            child: Center(
              child: Text(
                'No hay transacciones que coincidan con los filtros.',
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        filterWidgets,
        Expanded(
          child: ListView.builder(
            itemCount: filteredTransactions.length,
            itemBuilder: (context, index) {
              final tx = filteredTransactions[index];
              final isPurchase = tx.type == model.TransactionType.purchase;
              final icon = isPurchase
                  ? Icons.shopping_cart
                  : Icons.attach_money;
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
                  widget.onDelete(tx.id!);
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
                    onPressed: () => widget.onEdit(tx),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
