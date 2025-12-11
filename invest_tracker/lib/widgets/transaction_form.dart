// lib/widgets/transaction_form.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// CORREGIDO: Usar el prefijo 'model' para evitar conflictos
import '../models/transaction.dart' as model;
import '../services/database_helper.dart';

class TransactionForm extends StatefulWidget {
  // CORREGIDO: Usar model.Transaction
  final model.Transaction? transactionToEdit;
  // CORREGIDO: Usar model.TransactionType
  final model.TransactionType? initialType;

  const TransactionForm({super.key, this.transactionToEdit, this.initialType});

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  // CORREGIDO: Usar model.TransactionType
  late model.TransactionType _selectedType;
  late String _assetName;
  late double _price;
  late double _quantity;
  late DateTime _selectedDate;

  // Controladores para los campos de texto
  final TextEditingController _assetController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _totalValueController = TextEditingController();

  List<String> _uniqueAssetNames = [];
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    // CORREGIDO: Usar model.TransactionType
    _selectedType =
        widget.transactionToEdit?.type ??
        widget.initialType ??
        model.TransactionType.purchase;
    _isEditing = widget.transactionToEdit != null;
    _loadAssetNames();

    if (_isEditing) {
      final tx = widget.transactionToEdit!;
      _assetController.text = tx.assetName;
      _priceController.text = tx.price.toStringAsFixed(2);
      _quantityController.text = tx.quantity.toString();
      _totalValueController.text = tx.totalValue.toStringAsFixed(2);
      _assetName = tx.assetName;
      _price = tx.price;
      _quantity = tx.quantity;
      _selectedDate = tx.date;
    } else {
      _selectedDate = DateTime.now();
      _price = 0.0;
      _quantity = 0.0;
    }

    // Escuchar cambios para calcular el valor total
    _priceController.addListener(_calculateTotal);
    _quantityController.addListener(_calculateTotal);
  }

  @override
  void dispose() {
    _priceController.removeListener(_calculateTotal);
    _quantityController.removeListener(_calculateTotal);
    _priceController.dispose();
    _quantityController.dispose();
    _assetController.dispose();
    _totalValueController.dispose();
    super.dispose();
  }

  // Carga los nombres de activos existentes para el autocompletado
  void _loadAssetNames() async {
    _uniqueAssetNames = await DatabaseHelper.instance.getUniqueAssetNames();
    setState(() {}); // Actualiza la UI para el autocompletado
  }

  // Calcula el valor total (solo para COMPRAS)
  void _calculateTotal() {
    // CORREGIDO: Usar model.TransactionType.purchase
    if (_selectedType == model.TransactionType.purchase) {
      double price = double.tryParse(_priceController.text) ?? 0.0;
      double quantity = double.tryParse(_quantityController.text) ?? 0.0;
      double total = price * quantity;

      // Actualiza el controlador sin causar un loop, si no está siendo editado por el usuario
      if (_totalValueController.text != total.toStringAsFixed(2)) {
        _totalValueController.text = total.toStringAsFixed(2);
      }
      _price = price;
      _quantity = quantity;
    }
  }

  // Abre el selector de fecha
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      // También permite seleccionar la hora para mayor precisión
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      if (timePicked != null) {
        setState(() {
          _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            timePicked.hour,
            timePicked.minute,
          );
        });
      } else {
        setState(() {
          _selectedDate = picked;
        });
      }
    }
  }

  // Guarda/Actualiza la transacción
  void _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // CORREGIDO: Usar model.Transaction y model.TransactionType
      final newTransaction = model.Transaction(
        id: widget.transactionToEdit?.id,
        assetName: _assetName.toUpperCase().trim(),
        type: _selectedType,
        price:
            _selectedType ==
                model
                    .TransactionType
                    .purchase // <-- CORREGIDO
            ? _price
            : double.tryParse(_priceController.text)!,
        quantity:
            _selectedType ==
                model
                    .TransactionType
                    .purchase // <-- CORREGIDO
            ? _quantity
            : 1.0,
        totalValue: double.tryParse(_totalValueController.text)!,
        date: _selectedDate,
      );

      if (_isEditing) {
        await DatabaseHelper.instance.updateTransaction(newTransaction);
      } else {
        await DatabaseHelper.instance.insertTransaction(newTransaction);
      }

      // Corrección de "Don't use 'BuildContext' across async gaps"
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // CORREGIDO: El título ahora usa el prefijo
    final title = _isEditing
        ? 'Editar Transacción'
        : 'Nueva ${_selectedType == model.TransactionType.purchase ? 'Compra' : 'Provento'}';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Título
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),

              // Selector de Tipo de Transacción (solo si no estamos editando o tipo inicial no está definido)
              if (!_isEditing)
                // CORREGIDO: Usar model.TransactionType
                DropdownButtonFormField<model.TransactionType>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    // CORREGIDO: Usar model.TransactionType
                    DropdownMenuItem(
                      value: model.TransactionType.purchase,
                      child: Text('Compra'),
                    ),
                    DropdownMenuItem(
                      value: model.TransactionType.dividend,
                      child: Text('Provento/Dividendo'),
                    ),
                  ],
                  // CORREGIDO: Usar model.TransactionType
                  onChanged: (model.TransactionType? newValue) {
                    setState(() {
                      _selectedType = newValue!;
                      // Limpiar campos si el tipo cambia de compra a provento
                      if (_selectedType == model.TransactionType.dividend) {
                        // <-- CORREGIDO
                        _priceController.clear();
                        _quantityController.clear();
                        _totalValueController.clear();
                      }
                    });
                  },
                ),
              const SizedBox(height: 15),

              // Campo de Nombre del Activo (con autocompletar)
              Autocomplete<String>(
                // ... (el resto de Autocomplete no necesita cambios de prefijo)
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return _uniqueAssetNames.where((String option) {
                    return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                  });
                },

                // CORREGIDO: Usar model.Transaction
                initialValue: _isEditing
                    ? TextEditingValue(
                        text: widget.transactionToEdit!.assetName,
                      )
                    : null,
                onSelected: (String selection) {
                  _assetName = selection;
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      _assetController.text = controller.text;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        // CORREGIDO: Usar model.TransactionType
                        decoration: InputDecoration(
                          labelText:
                              _selectedType == model.TransactionType.purchase
                              ? 'Nombre del Activo (Acción/FII)'
                              : 'Activo que pagó el Provento',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Introduce el nombre del activo';
                          }
                          return null;
                        },
                        onChanged: (value) => _assetName = value,
                        onSaved: (value) => _assetName = value!,
                      );
                    },
              ),
              const SizedBox(height: 15),

              // Campo de Precio Unitario / Monto del Provento
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                // CORREGIDO: Usar model.TransactionType
                decoration: InputDecoration(
                  labelText: _selectedType == model.TransactionType.purchase
                      ? 'Precio Unitario'
                      : 'Monto del Provento (\$)',
                ),
                validator: (value) {
                  if (value == null ||
                      double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'Introduce un valor positivo';
                  }
                  return null;
                },
                onSaved: (value) => _price = double.parse(value!),
              ),
              const SizedBox(height: 15),

              // Campo de Cantidad (solo para Compras)
              // CORREGIDO: Usar model.TransactionType
              if (_selectedType == model.TransactionType.purchase)
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                  validator: (value) {
                    if (value == null ||
                        double.tryParse(value) == null ||
                        double.parse(value) <= 0) {
                      return 'Introduce una cantidad válida';
                    }
                    return null;
                  },
                  onSaved: (value) => _quantity = double.parse(value!),
                ),
              const SizedBox(height: 15),

              // Campo de Valor Total (Editable para provento, calculado para compra)
              TextFormField(
                controller: _totalValueController,
                keyboardType: TextInputType.number,
                // CORREGIDO: Usar model.TransactionType
                readOnly: _selectedType == model.TransactionType.purchase,
                decoration: const InputDecoration(
                  labelText: 'Valor Total (\$)',
                ),
                validator: (value) {
                  if (value == null ||
                      double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'Introduce un valor total positivo';
                  }
                  return null;
                },
                onSaved: (value) => {}, // Ya guardado en _calculateTotal/precio
              ),
              const SizedBox(height: 20),

              // Selector de Fecha
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Fecha: ${DateFormat('yyyy-MM-dd HH:mm').format(_selectedDate)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _selectDate(context),
                    child: const Text('Seleccionar Fecha'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Botón de Guardar
              ElevatedButton(
                onPressed: _saveTransaction,
                child: Text(
                  _isEditing ? 'Guardar Cambios' : 'Añadir Transacción',
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
