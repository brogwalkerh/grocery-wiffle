import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groceryListProvider(widget.listId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.list?.name ?? 'Loading...'),
        actions: [
          if (state.list != null && state.list!.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.compare_arrows),
              onPressed: () => context.push('/compare/${widget.listId}'),
              tooltip: 'Compare Prices',
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'rename') {
                final newName = await _showRenameDialog(state.list?.name ?? '');
                if (newName != null) {
                  ref
                      .read(groceryListProvider(widget.listId).notifier)
                      .updateName(newName);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Rename List'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(state, theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }

  Widget _buildBody(GroceryListState state, ThemeData theme) {
    if (state.isLoading && state.list == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.list == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load list',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref
                  .read(groceryListProvider(widget.listId).notifier)
                  .loadList(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final list = state.list!;

    if (list.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_shopping_cart,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'List is empty',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add items to start comparing prices',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: list.items.length,
      onReorder: (oldIndex, newIndex) {
        // Handle reordering
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        // TODO: Implement reordering
      },
      itemBuilder: (context, index) {
        final item = list.items[index];
        return GroceryListItemTile(
          key: ValueKey(item.id),
          item: item,
          onToggle: (checked) {
            final updatedItem = item.copyWith(isChecked: checked);
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
        );
      },
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
