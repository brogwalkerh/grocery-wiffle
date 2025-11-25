import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../data/models/grocery_list.dart';

/// Bottom sheet for adding or editing a grocery list item.
class AddItemSheet extends StatefulWidget {
  /// Existing item to edit, if any.
  final GroceryListItem? existingItem;

  const AddItemSheet({
    super.key,
    this.existingItem,
  });

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;
  String? _selectedUnit;

  final _formKey = GlobalKey<FormState>();
  bool get _isEditing => widget.existingItem != null;

  static const _units = [
    'each',
    'lb',
    'oz',
    'gallon',
    'liter',
    'dozen',
    'pack',
    'bag',
    'box',
    'bottle',
    'can',
    'jar',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingItem?.name);
    _quantityController = TextEditingController(
      text: widget.existingItem?.quantity.toString() ?? '1',
    );
    _notesController = TextEditingController(text: widget.existingItem?.notes);
    _selectedUnit = widget.existingItem?.unit;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final item = GroceryListItem(
        id: widget.existingItem?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        quantity: double.tryParse(_quantityController.text) ?? 1.0,
        unit: _selectedUnit,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        productId: widget.existingItem?.productId,
        position: widget.existingItem?.position ?? 0,
        isChecked: widget.existingItem?.isChecked ?? false,
      );

      Navigator.pop(context, item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit Item' : 'Add Item',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Name field
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    hintText: 'e.g., Milk, Bread, Eggs',
                    prefixIcon: Icon(Icons.shopping_basket_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an item name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Quantity and Unit row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final qty = double.tryParse(value);
                            if (qty == null || qty <= 0) {
                              return 'Invalid quantity';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          prefixIcon: Icon(Icons.straighten),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('No unit'),
                          ),
                          ..._units.map((unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedUnit = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Notes field
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Any special instructions',
                    prefixIcon: Icon(Icons.notes),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                FilledButton.icon(
                  onPressed: _submit,
                  icon: Icon(_isEditing ? Icons.save : Icons.add),
                  label: Text(_isEditing ? 'Save Changes' : 'Add to List'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
