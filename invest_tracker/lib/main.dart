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
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'services/backup_restore_service.dart'; // NUEVO

// CAMBIO 1: Inicializar con locale 'pt_BR'
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Inicializar para Portugués (Brasil), compatible con Real Brasileño
    await initializeDateFormatting('pt_BR', null);
  } catch (e) {
    // En caso de error, la app seguirá funcionando con la configuración por defecto
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
  final BackupRestoreService _backupService = BackupRestoreService();

  model.TransactionType? _historyFilterType;
  DateTime? _historyFilterDate;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  // CORREGIDO: Declarar explícitamente Future<void>
  Future<void> _loadTransactions() async {
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
      date = DateTime.tryParse('$dateKey-01');
    } else if (dateKey.length == 4) {
      date = DateTime.tryParse('$dateKey-01-01');
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

  // lib/main.dart

  Future<void> _exportDatabase(BuildContext context) async {
    // --- LÓGICA DE PERMISOS ACTUALIZADA ---
    // Solo pedimos permiso si NO es Android 13+ (SDK 33+).
    // Como saber el SDK exacto es difícil sin plugins extra,
    // intentamos pedirlo. Si el sistema dice que está "restringido" o "denegado permanentemente"
    // (que es lo que pasa en Android 13+), asumimos que podemos escribir en Descargas y continuamos.

    if (Platform.isAndroid) {
      // Verificamos el estado actual sin pedirlo primero
      var status = await Permission.storage.status;

      // Si no está concedido, intentamos pedirlo
      if (!status.isGranted) {
        // En Android 13+, request() puede devolver permanentlyDenied inmediatamente.
        // No bloqueamos el flujo por esto.
        final result = await Permission.storage.request();

        // Si es Android 11/12/13+, escribir en Downloads PÚBLICOS no requiere permiso.
        // Solo bloqueamos si el usuario denegó explícitamente en versiones viejas (Android 9 o menos).
        // Para simplificar: IGNORAMOS el resultado del permiso y PROBAMOS escribir.
        // Si falla la escritura, el bloque try-catch del servicio lo capturará.
      }
    }
    // --------------------------------------

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exportando base de datos...')),
    );

    // Llamamos al servicio. Si falla por permisos reales, devolverá el mensaje de error.
    final resultPath = await _backupService.exportDatabase();

    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();

      if (resultPath != null && !resultPath.startsWith('Error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('¡Backup guardado en Descargas!'),
            backgroundColor: Colors.green, // Visualmente mejor
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        // Opcional: Recargar transacciones si fuera necesario
        // _loadTransactions();
      } else {
        // Aquí caeremos si realmente falló la escritura
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fallo: ${resultPath ?? 'Error desconocido'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // CORREGIDO: Declarar explícitamente Future<void>
  Future<void> _importDatabase(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Importando base de datos...')),
    );

    final resultMessage = await _backupService.importDatabase(
      // 1. Callback para cerrar DB: Usa el helper
      onDbReplaced: () => DatabaseHelper.instance.closeDatabase(),
      // 2. Callback para reabrir DB y recargar datos: Usa el método existente
      onDbLoad: _loadTransactions,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      if (resultMessage == "Selección de archivo cancelada.") {
        return;
      } else if (resultMessage != null && !resultMessage.startsWith('Error')) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(resultMessage)));
        // La vista ya se recargó a través del callback onDbLoad
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resultMessage ?? 'Fallo al importar.')),
        );
      }
    }
  }

  // Diálogo para mostrar las opciones de Exportar/Importar
  void _showBackupRestoreDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Copia de Seguridad y Restauración"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Exportar Base de Datos'),
                subtitle: const Text(
                  'Guarda una copia (.db) en la carpeta Descargas del teléfono.',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _exportDatabase(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload),
                title: const Text('Importar Base de Datos'),
                subtitle: const Text(
                  'Reemplaza la DB actual con un archivo de backup (.db).',
                ),
                onTap: () async {
                  // Pedir confirmación antes de sobreescribir
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Confirmar Importación"),
                      content: const Text(
                        "¿Estás seguro de que quieres reemplazar la base de datos actual? Esta acción es irreversible.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancelar"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            "Importar",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    Navigator.of(context).pop(); // Cierra el primer diálogo
                    await _importDatabase(context);
                  }
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cerrar"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
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
              // Eliminado el espacio inicial, ya incluido en el format
              currencyFormat.format(_totalInvested),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),

        // NUEVO: Botón de configuración/backup
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showBackupRestoreDialog,
            tooltip: 'Configuración y Backup',
          ),
        ],
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
