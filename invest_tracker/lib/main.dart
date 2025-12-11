// lib/main.dart

import 'package:flutter/material.dart';

import 'services/database_helper.dart';
import 'widgets/transaction_form.dart';
import 'widgets/dashboard_view.dart';
import 'widgets/history_view.dart';
import 'models/transaction.dart' as model; // <-- Importación con prefijo

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  // CORREGIDO: Usar model.Transaction
  List<model.Transaction> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  // Carga todas las transacciones desde la base de datos
  void _loadTransactions() async {
    // database_helper.getAllTransactions ya devuelve List<model.Transaction>
    final transactions = await DatabaseHelper.instance.getAllTransactions();
    setState(() {
      _transactions = transactions;
      _isLoading = false;
    });
  }

  // Muestra el formulario para añadir/editar
  void _showTransactionForm({
    // CORREGIDO: Usar model.Transaction y model.TransactionType
    model.Transaction? transaction,
    model.TransactionType? type,
  }) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Para que el teclado no tape el formulario
      builder: (_) =>
          TransactionForm(transactionToEdit: transaction, initialType: type),
    );

    if (result == true) {
      _loadTransactions(); // Recargar si se realizó una operación exitosa
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Contenido de la pantalla principal
  List<Widget> get _widgetOptions => <Widget>[
    // CORREGIDO: Pasar la lista de transacciones corregida
    DashboardView(transactions: _transactions),
    HistoryView(
      transactions: _transactions,
      // ¡CORRECCIÓN CLAVE! Adaptar el argumento posicional (tx)
      // que HistoryView pasa, al argumento nombrado (transaction) que
      // _showTransactionForm espera.
      onEdit: (tx) => _showTransactionForm(transaction: tx),
      onDelete: (int id) async {
        await DatabaseHelper.instance.deleteTransaction(id);
        _loadTransactions();
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Cartera')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _widgetOptions.elementAt(_selectedIndex),

      // Botón flotante para añadir nuevas transacciones
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton.extended(
            heroTag: 'addPurchase',
            label: const Text('Compra'),
            icon: const Icon(Icons.shopping_cart),
            // CORREGIDO: Usar model.TransactionType.purchase
            onPressed: () =>
                _showTransactionForm(type: model.TransactionType.purchase),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'addDividend',
            label: const Text('Provento'),
            icon: const Icon(Icons.attach_money),
            // CORREGIDO: Usar model.TransactionType.dividend
            onPressed: () =>
                _showTransactionForm(type: model.TransactionType.dividend),
          ),
        ],
      ),

      // Barra de navegación inferior
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
