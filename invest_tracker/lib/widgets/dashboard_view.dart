// lib/widgets/dashboard_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// NOTA: Se eliminó la importación de fl_chart ya que no se usa.

// Usar prefijo model para evitar conflictos
import '../models/transaction.dart' as model;
import '../utils/calculations.dart';

class DashboardView extends StatefulWidget {
  final List<model.Transaction> transactions;

  const DashboardView({super.key, required this.transactions});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  // 'month' o 'year'
  String _groupBy = 'month';
  int _selectedYear = DateTime.now().year;

  // Resumen por activo (ticker -> AssetSummary)
  Map<String, AssetSummary> _assetSummaries = {};

  // Datos de proventos (Mes/Año -> Monto)
  Map<String, double> _dividendData = {};

  // Años únicos presentes en las transacciones
  List<int> get uniqueYears {
    final years = widget.transactions.map((t) => t.date.year).toSet();
    if (years.isEmpty) return [DateTime.now().year];
    final list = years.toList();
    list.sort((a, b) => b.compareTo(a)); // más reciente primero
    return list;
  }

  @override
  void initState() {
    super.initState();
    _calculateAllStats();
  }

  @override
  void didUpdateWidget(covariant DashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transactions != oldWidget.transactions) {
      _calculateAllStats();
    }
  }

  void _calculateAllStats() {
    if (widget.transactions.isEmpty) {
      setState(() {
        _assetSummaries = {};
        _dividendData = {};
      });
      return;
    }

    // Ajustar año seleccionado si ya no existe en los datos
    final years = uniqueYears;
    if (!years.contains(_selectedYear)) {
      _selectedYear = years.first;
    }

    setState(() {
      _assetSummaries = calculateAssetSummary(widget.transactions);
      // Usamos la misma lógica de cálculo, pero ahora para mostrar en lista
      _dividendData = _groupBy == 'month'
          ? calculateMonthlyDividends(widget.transactions, _selectedYear)
          : calculateYearlyDividends(widget.transactions);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) {
      return const Center(
        child: Text('Aún no tienes transacciones registradas.'),
      );
    }

    final currencyFormat = NumberFormat.currency(locale: 'es_ES', symbol: '\$');

    // Filtramos para mostrar solo los meses/años que tienen proventos (> 0)
    final dividendEntries = _dividendData.entries
        .where((entry) => entry.value > 0)
        .toList();

    // Calcular el total de lo que se muestra en pantalla
    final double totalDisplayed = dividendEntries.fold(
      0.0,
      (prev, element) => prev + element.value,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // --- SECCIÓN 1: RESUMEN DE ACTIVOS ---
          const Text(
            '📊 Resumen de Inversiones por Activo',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          ..._assetSummaries.entries.map((entry) {
            final summary = entry.value;
            final valorization = summary.currentValue - summary.investedValue;
            final isPositive = valorization >= 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 2,
              child: ListTile(
                title: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Posición: ${currencyFormat.format(summary.currentValue)} - '
                  'Cantidad: ${summary.quantity.toStringAsFixed(0)}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Medio: ${currencyFormat.format(summary.averagePrice)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Valorización: ${currencyFormat.format(valorization)}',
                      style: TextStyle(
                        color: isPositive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const Divider(height: 30, thickness: 2),

          // --- SECCIÓN 2: PROVENTOS (LISTA) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '💰 Proventos Recibidos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              // Chip para mostrar el total del periodo
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Total: ${currencyFormat.format(totalDisplayed)}',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Filtros (Mes/Año y Selector de Año)
          Row(
            children: [
              DropdownButton<String>(
                value: _groupBy,
                items: const [
                  DropdownMenuItem(
                    value: 'month',
                    child: Text('Ver por Meses'),
                  ),
                  DropdownMenuItem(value: 'year', child: Text('Ver por Años')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _groupBy = value;
                    _calculateAllStats();
                  });
                },
              ),
              const SizedBox(width: 20),
              // Selector de Año (solo visible si se agrupa por mes)
              if (_groupBy == 'month' && uniqueYears.length > 1)
                DropdownButton<int>(
                  value: _selectedYear,
                  items: uniqueYears
                      .map(
                        (year) => DropdownMenuItem(
                          value: year,
                          child: Text('Año $year'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedYear = value;
                      _calculateAllStats();
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Lista de Proventos
          if (dividendEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No hay proventos registrados para este periodo.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            ...dividendEntries.map((entry) {
              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal[100],
                    child: const Icon(Icons.attach_money, color: Colors.teal),
                  ),
                  title: Text(
                    entry.key, // Nombre del Mes o el Año
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Text(
                    currencyFormat.format(entry.value),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ),
              );
            }),

          const SizedBox(height: 40), // Espacio final
        ],
      ),
    );
  }
}
