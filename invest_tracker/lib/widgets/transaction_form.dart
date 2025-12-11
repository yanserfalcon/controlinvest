// lib/widgets/transaction_form.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart' as model;
import '../services/database_helper.dart';

class TransactionForm extends StatefulWidget {
  final model.Transaction? transactionToEdit;
  final model.TransactionType? initialType;

  const TransactionForm({super.key, this.transactionToEdit, this.initialType});

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late model.TransactionType _selectedType;
  late String _assetName;
  late double _price;
  late double _quantity;
  late DateTime _selectedDate;

  final TextEditingController _assetController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _totalValueController = TextEditingController();

  List<String> _uniqueAssetNames = [];
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadUniqueAssets();
    _isEditing = widget.transactionToEdit != null;

    if (_isEditing) {
      final tx = widget.transactionToEdit!;
      _selectedType = tx.type;
      _assetName = tx.assetName;
      _price = tx.price;
      _quantity = tx.quantity;
      _selectedDate = tx.date;

      _assetController.text = _assetName;
      _priceController.text = _price.toStringAsFixed(4);
      _quantityController.text = _quantity.toStringAsFixed(4);
      _totalValueController.text = tx.totalValue.toStringAsFixed(2);
    } else {
      _selectedType = widget.initialType ?? model.TransactionType.purchase;
      _assetName = '';
      _price = 0.0;
      _quantity = 0.0;
      _selectedDate = DateTime.now();
      _totalValueController.text = '';
    }

    // Escuchar cambios para calcular el valor total automáticamente (solo Compra)
    _priceController.addListener(_calculateTotal);
    _quantityController.addListener(_calculateTotal);
    // Escuchar cambios para actualizar Precio y Cantidad si se modifica el Total (solo Compra)
    _totalValueController.addListener(_calculatePriceAndQuantity);
  }

  void _loadUniqueAssets() async {
    final assets = await DatabaseHelper.instance.getUniqueAssetNames();
    setState(() {
      _uniqueAssetNames = assets;
    });
  }

  @override
  void dispose() {
    _priceController.removeListener(_calculateTotal);
    _quantityController.removeListener(_calculateTotal);
    _totalValueController.removeListener(_calculatePriceAndQuantity);
    _assetController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _totalValueController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    if (_selectedType == model.TransactionType.purchase) {
      final price = double.tryParse(_priceController.text) ?? 0.0;
      final quantity = double.tryParse(_quantityController.text) ?? 0.0;

      // Desactivar el listener de _totalValueController temporalmente para evitar loops
      _totalValueController.removeListener(_calculatePriceAndQuantity);

      final total = price * quantity;
      // Actualizar solo si el cálculo da un resultado válido y no es el valor actual
      if (total >= 0 && total != double.tryParse(_totalValueController.text)) {
        _totalValueController.text = total.toStringAsFixed(2);
      }

      _totalValueController.addListener(_calculatePriceAndQuantity);
    }
  }

  void _calculatePriceAndQuantity() {
    // Esta lógica solo aplica para COMPRA
    if (_selectedType == model.TransactionType.purchase) {
      final totalValue = double.tryParse(_totalValueController.text) ?? 0.0;
      final quantity = double.tryParse(_quantityController.text) ?? 0.0;

      // Si el usuario modifica el Total y hay Cantidad, calcular el Precio.
      if (totalValue > 0 && quantity > 0) {
        final price = totalValue / quantity;
        // Desactivar el listener de priceController temporalmente para evitar loops
        _priceController.removeListener(_calculateTotal);
        _priceController.text = price.toStringAsFixed(4);
        _priceController.addListener(_calculateTotal);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final totalValue = double.parse(_totalValueController.text);

      // Si es Provento, Cantidad y Precio no son relevantes, se fijan a 0.
      final quantity = _selectedType == model.TransactionType.dividend
          ? 0.0
          : (double.tryParse(_quantityController.text) ?? 0.0);
      final price = _selectedType == model.TransactionType.dividend
          ? 0.0
          : (double.tryParse(_priceController.text) ?? 0.0);

      final transaction = model.Transaction(
        id: widget.transactionToEdit?.id,
        type: _selectedType,
        assetName: _assetController.text
            .toUpperCase(), // Asegurar mayúsculas en DB
        price: price,
        quantity: quantity,
        totalValue: totalValue,
        date: _selectedDate,
      );

      if (_isEditing) {
        await DatabaseHelper.instance.updateTransaction(transaction);
      } else {
        await DatabaseHelper.instance.insertTransaction(transaction);
      }

      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determinar si los campos de Cantidad y Precio deben mostrarse
    final showPriceAndQuantity =
        _selectedType == model.TransactionType.purchase;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _isEditing ? 'Editar Transacción' : 'Nueva Transacción',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Selector de Tipo de Transacción
              DropdownButtonFormField<model.TransactionType>(
                decoration: const InputDecoration(
                  labelText: 'Tipo de Transacción',
                ),
                value: _selectedType,
                items: model.TransactionType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(
                      type == model.TransactionType.purchase
                          ? 'Compra'
                          : 'Provento',
                    ),
                  );
                }).toList(),
                onChanged: (model.TransactionType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedType = newValue;
                      // Limpiar campos relacionados al cambiar de tipo
                      _priceController.text = '';
                      _quantityController.text = '';
                      _totalValueController.text = '';
                    });
                  }
                },
              ),
              const SizedBox(height: 10),

              // --- CAMPO DE NOMBRE DEL ACTIVO CON AUTOCOMPLETADO Y MAYÚSCULAS ---
              Autocomplete<String>(
                // Suministra la lista de activos únicos
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  // Filtra las opciones, comparando en mayúsculas
                  return _uniqueAssetNames.where((String option) {
                    return option.contains(textEditingValue.text.toUpperCase());
                  });
                },
                // Al seleccionar, se actualiza el controlador
                onSelected: (String selection) {
                  _assetController.text = selection;
                },
                fieldViewBuilder:
                    (
                      BuildContext context,
                      TextEditingController fieldTextEditingController,
                      FocusNode fieldFocusNode,
                      VoidCallback onFieldSubmitted,
                    ) {
                      // Sincronizar el controlador local con el controlador del Autocomplete
                      _assetController.text = fieldTextEditingController.text;

                      return TextFormField(
                        controller: fieldTextEditingController,
                        focusNode: fieldFocusNode,
                        onFieldSubmitted: (value) {
                          onFieldSubmitted();
                        },
                        // Asegura que el texto ingresado sea mayúsculas
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Ticker (Ej: AAPL)',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Introduce el nombre del activo';
                          }
                          return null;
                        },
                        // onSaved se ejecuta al final
                        onSaved: (value) => _assetName = value!,
                      );
                    },
              ),
              const SizedBox(height: 10),

              // --- CAMPOS CONDICIONALES (Precio y Cantidad) ---
              if (showPriceAndQuantity)
                Row(
                  children: [
                    // Campo Precio
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Precio por Unidad (R\$)',
                        ),
                        validator: (value) {
                          if (value == null ||
                              double.tryParse(value) == null ||
                              double.parse(value) < 0) {
                            return 'Introduce un precio válido';
                          }
                          return null;
                        },
                        onSaved: (value) => _price = double.parse(value!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Campo Cantidad
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad',
                        ),
                        validator: (value) {
                          if (value == null ||
                              double.tryParse(value) == null ||
                              double.parse(value) <= 0) {
                            return 'Introduce una cantidad positiva';
                          }
                          return null;
                        },
                        onSaved: (value) => _quantity = double.parse(value!),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),

              // --- Campo Valor Total (Único para Proventos, Recalculado para Compra) ---
              TextFormField(
                controller: _totalValueController,
                keyboardType: TextInputType.number,
                // Etiqueta cambia según el tipo de transacción
                decoration: InputDecoration(
                  labelText: showPriceAndQuantity
                      ? 'Valor Total (Calculado)'
                      : 'Monto del Provento (R\$)',
                  // Si es compra, el campo es solo lectura (calculado)
                  suffixIcon: showPriceAndQuantity
                      ? const Icon(Icons.calculate, color: Colors.blue)
                      : null,
                ),
                readOnly: showPriceAndQuantity,
                validator: (value) {
                  if (value == null ||
                      double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'Introduce un valor total positivo';
                  }
                  return null;
                },
                onSaved: (value) => {},
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
