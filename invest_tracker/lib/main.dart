// lib/main.dart (CONTENIDO COMPLETO ACTUALIZADO)

import 'package:flutter/material.dart';
// Importar para localización y el método initializeDateFormatting
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'services/database_helper.dart';
import 'widgets/transaction_form.dart';
import 'widgets/dashboard_view.dart';
import 'widgets/history_view.dart';
import 'models/transaction.dart' as model;

// CAMBIO 1: Inicializar con locale 'pt_BR'
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Inicializar para Portugués (Brasil), compatible con Real Brasileño
    await initializeDateFormatting('pt_BR', null);
  } catch (e) {
    print('Error al inicializar datos de localización: $e');
  }

  runApp(const InvestmentTrackerApp());
}

class InvestmentTrackerApp extends StatelessWidget {
  const InvestmentTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Cartera de Inversiones',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  List<model.Transaction> _transactions = [];
  bool _isLoading = true;

  model.TransactionType? _historyFilterType;
  DateTime? _historyFilterDate;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() async {
    final transactions = await DatabaseHelper.instance.getAllTransactions();
    setState(() {
      _transactions = transactions;
      _isLoading = false;
    });
  }

  // NUEVO: Función para calcular el total invertido
  double get _totalInvested {
    return _transactions
        .where((t) => t.type == model.TransactionType.purchase)
        .fold(0.0, (sum, t) => sum + t.totalValue);
  }

  void _showTransactionForm({
    model.Transaction? transaction,
    model.TransactionType? type,
  }) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          TransactionForm(transactionToEdit: transaction, initialType: type),
    );

    if (result == true) {
      _loadTransactions();
    }
  }

  void _goToHistoryWithFilters({
    required model.TransactionType type,
    required String dateKey,
  }) {
    DateTime? date;

    if (dateKey.length == 7) {
      date = DateTime.tryParse('${dateKey}-01');
    } else if (dateKey.length == 4) {
      date = DateTime.tryParse('${dateKey}-01-01');
    }

    setState(() {
      _historyFilterType = type;
      _historyFilterDate = date;
      _selectedIndex = 1;
    });
  }

  void _onItemTapped(int index) {
    if (index == 0 || index == 1) {
      setState(() {
        _selectedIndex = index;
        if (index == 1) {
          _historyFilterType = null;
          _historyFilterDate = null;
        }
      });
    } else if (index == 2) {
      _showTransactionForm(type: model.TransactionType.purchase);
    } else if (index == 3) {
      _showTransactionForm(type: model.TransactionType.dividend);
    }
  }

  List<Widget> get _widgetOptions => <Widget>[
    DashboardView(
      transactions: _transactions,
      onDividendTap: _goToHistoryWithFilters,
    ),
    HistoryView(
      transactions: _transactions,
      initialFilterType: _historyFilterType,
      initialFilterDate: _historyFilterDate,
      onEdit: (tx) => _showTransactionForm(transaction: tx),
      onDelete: (int id) async {
        await DatabaseHelper.instance.deleteTransaction(id);
        _loadTransactions();
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // CAMBIO 2: Formato de moneda para R$ (Real Brasileño)
    final currencyFormat = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Mi Cartera'),
            // CAMBIO 3: Mostrar el total invertido
            Text(
              ' ${currencyFormat.format(_totalInvested)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _widgetOptions.elementAt(_selectedIndex),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Compra',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Provento',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
