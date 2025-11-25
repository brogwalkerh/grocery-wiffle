import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/providers/providers.dart';
import '../widgets/grocery_list_card.dart';
import '../widgets/create_list_dialog.dart';

/// Screen showing all grocery lists.
class GroceryListsScreen extends ConsumerStatefulWidget {
  const GroceryListsScreen({super.key});

  @override
  ConsumerState<GroceryListsScreen> createState() => _GroceryListsScreenState();
}

class _GroceryListsScreenState extends ConsumerState<GroceryListsScreen> {
  @override
  void initState() {
    super.initState();
    // Load lists when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(groceryListsProvider.notifier).loadLists();
    });
  }

  Future<void> _showCreateListDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const CreateListDialog(),
    );

    if (name != null && name.isNotEmpty) {
      final list = await ref.read(groceryListsProvider.notifier).createList(name);
      if (list != null && mounted) {
        context.push('/list/${list.id}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groceryListsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Grocery Lists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(groceryListsProvider.notifier).loadLists(),
        child: _buildBody(state, theme),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateListDialog,
        icon: const Icon(Icons.add),
        label: const Text('New List'),
      ),
    );
  }

  Widget _buildBody(GroceryListsState state, ThemeData theme) {
    if (state.isLoading && state.lists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.lists.isEmpty) {
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
              'Failed to load lists',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.read(groceryListsProvider.notifier).loadLists(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.lists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No grocery lists yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first list to start comparing prices',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.lists.length,
      itemBuilder: (context, index) {
        final list = state.lists[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GroceryListCard(
            list: list,
            onTap: () => context.push('/list/${list.id}'),
            onDelete: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete List'),
                  content: Text('Are you sure you want to delete "${list.name}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                ref.read(groceryListsProvider.notifier).deleteList(list.id);
              }
            },
            onCompare: () => context.push('/compare/${list.id}'),
          ),
        );
      },
    );
  }
}
