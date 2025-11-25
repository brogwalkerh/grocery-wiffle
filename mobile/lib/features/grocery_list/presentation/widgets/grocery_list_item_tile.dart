import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../data/models/grocery_list.dart';

/// Tile widget for displaying a grocery list item.
class GroceryListItemTile extends StatelessWidget {
  /// The item to display.
  final GroceryListItem item;

  /// Callback when item is toggled.
  final ValueChanged<bool>? onToggle;

  /// Callback when edit is requested.
  final VoidCallback? onEdit;

  /// Callback when delete is requested.
  final VoidCallback? onDelete;

  const GroceryListItemTile({
    super.key,
    required this.item,
    this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: ValueKey(item.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.4,
          children: [
            SlidableAction(
              onPressed: (_) => onEdit?.call(),
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              icon: Icons.edit,
              label: 'Edit',
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
            ),
            SlidableAction(
              onPressed: (_) => onDelete?.call(),
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
              icon: Icons.delete,
              label: 'Delete',
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Checkbox(
              value: item.isChecked,
              onChanged: (value) => onToggle?.call(value ?? false),
            ),
            title: Text(
              item.name,
              style: TextStyle(
                decoration: item.isChecked ? TextDecoration.lineThrough : null,
                color: item.isChecked
                    ? theme.colorScheme.onSurfaceVariant
                    : null,
              ),
            ),
            subtitle: _buildSubtitle(theme),
            trailing: item.notes != null && item.notes!.isNotEmpty
                ? Icon(
                    Icons.notes,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : null,
            onTap: () => onToggle?.call(!item.isChecked),
          ),
        ),
      ),
    );
  }

  Widget? _buildSubtitle(ThemeData theme) {
    final parts = <String>[];

    if (item.quantity != 1.0 || item.unit != null) {
      final qty = Formatters.formatQuantity(item.quantity);
      if (item.unit != null) {
        parts.add('$qty ${item.unit}');
      } else {
        parts.add('Qty: $qty');
      }
    }

    if (parts.isEmpty) {
      return null;
    }

    return Text(
      parts.join(' • '),
      style: TextStyle(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
