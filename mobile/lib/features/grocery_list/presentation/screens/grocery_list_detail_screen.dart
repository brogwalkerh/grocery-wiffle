import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/models/grocery_list.dart';
import '../../../../data/providers/providers.dart';
import '../widgets/grocery_list_item_tile.dart';
import '../widgets/add_item_sheet.dart';

/// Screen showing details of a single grocery list.
class GroceryListDetailScreen extends ConsumerStatefulWidget {
  /// The list ID.
  final String listId;

  const GroceryListDetailScreen({
    super.key,
    required this.listId,
  });

  @override
  ConsumerState<GroceryListDetailScreen> createState() =>
      _GroceryListDetailScreenState();
}

class _GroceryListDetailScreenState
    extends ConsumerState<GroceryListDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(groceryListProvider(widget.listId).notifier).loadList();
    });
  }

  Future<void> _showAddItemSheet() async {
    final item = await showModalBottomSheet<GroceryListItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const AddItemSheet(),
    );

    if (item != null) {
      await ref.read(groceryListProvider(widget.listId).notifier).addItem(item);
    }
  }

  Future<void> _showQuickAdd() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Quick Add'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter item name',
              prefixIcon: Icon(Icons.add_shopping_cart),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.pop(context, value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      final item = GroceryListItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: result,
        quantity: 1,
        position: 0,
      );
      await ref.read(groceryListProvider(widget.listId).notifier).addItem(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groceryListProvider(widget.listId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            // Modern header
            _buildHeader(theme, state),

            // Body
            Expanded(
              child: _buildBody(state, theme),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, GroceryListState state) {
    final checkedCount =
        state.list?.items.where((i) => i.isChecked).length ?? 0;
    final totalCount = state.list?.items.length ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button and actions row
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.adaptive.arrow_back),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final newName =
                        await _showRenameDialog(state.list?.name ?? '');
                    if (newName != null) {
                      ref
                          .read(groceryListProvider(widget.listId).notifier)
                          .updateName(newName);
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              state.list?.name ?? 'Loading...',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (totalCount > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$checkedCount of $totalCount items checked',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Quick add button
              IconButton(
                onPressed: _showQuickAdd,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Quick Add',
              ),

              // Compare prices button
              if (state.list != null && state.list!.items.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => context.push('/compare/${widget.listId}'),
                  icon: const Icon(Icons.compare_arrows, size: 18),
                  label: const Text('Compare'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
            ],
          ),

          // Progress bar
          if (totalCount > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalCount > 0 ? checkedCount / totalCount : 0,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  checkedCount == totalCount && totalCount > 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.tertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(GroceryListState state, ThemeData theme) {
    if (state.isLoading && state.list == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.list == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 40,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Failed to load list',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => ref
                    .read(groceryListProvider(widget.listId).notifier)
                    .loadList(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Handle case where list is still null (shouldn't happen but safety check)
    if (state.list == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final list = state.list!;

    if (list.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.add_shopping_cart,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Your list is empty',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add items to start comparing prices\nacross different stores',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showQuickAdd,
                    icon: const Icon(Icons.flash_on, size: 18),
                    label: const Text('Quick Add'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _showAddItemSheet,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Group items by checked status
    final uncheckedItems = list.items.where((i) => !i.isChecked).toList();
    final checkedItems = list.items.where((i) => i.isChecked).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        // Unchecked items
        ...uncheckedItems.map((item) => GroceryListItemTile(
              key: ValueKey(item.id),
              item: item,
              onToggle: (checked) {
                final updatedItem = item.copyWith(isChecked: checked);
                ref
                    .read(groceryListProvider(widget.listId).notifier)
                    .updateItem(updatedItem);
              },
              onQuantityChanged: (quantity) {
                final updatedItem = item.copyWith(quantity: quantity);
                ref
                    .read(groceryListProvider(widget.listId).notifier)
                    .updateItem(updatedItem);
              },
              onEdit: () async {
                final editedItem = await showModalBottomSheet<GroceryListItem>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => AddItemSheet(existingItem: item),
                );

                if (editedItem != null) {
                  ref
                      .read(groceryListProvider(widget.listId).notifier)
                      .updateItem(editedItem);
                }
              },
              onDelete: () {
                ref
                    .read(groceryListProvider(widget.listId).notifier)
                    .removeItem(item.id);
              },
            )),

        // Divider and checked items
        if (checkedItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Checked off',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${checkedItems.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // Clear all checked items
                  for (final item in checkedItems) {
                    ref
                        .read(groceryListProvider(widget.listId).notifier)
                        .removeItem(item.id);
                  }
                },
                child: const Text('Clear all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...checkedItems.map((item) => Opacity(
                opacity: 0.6,
                child: GroceryListItemTile(
                  key: ValueKey(item.id),
                  item: item,
                  onToggle: (checked) {
                    final updatedItem = item.copyWith(isChecked: checked);
                    ref
                        .read(groceryListProvider(widget.listId).notifier)
                        .updateItem(updatedItem);
                  },
                  onQuantityChanged: (quantity) {
                    final updatedItem = item.copyWith(quantity: quantity);
                    ref
                        .read(groceryListProvider(widget.listId).notifier)
                        .updateItem(updatedItem);
                  },
                  onEdit: () async {
                    final editedItem =
                        await showModalBottomSheet<GroceryListItem>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (context) => AddItemSheet(existingItem: item),
                    );

                    if (editedItem != null) {
                      ref
                          .read(groceryListProvider(widget.listId).notifier)
                          .updateItem(editedItem);
                    }
                  },
                  onDelete: () {
                    ref
                        .read(groceryListProvider(widget.listId).notifier)
                        .removeItem(item.id);
                  },
                ),
              )),
        ],
      ],
    );
  }

  Future<String?> _showRenameDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename List'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'List Name',
            hintText: 'Enter list name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
