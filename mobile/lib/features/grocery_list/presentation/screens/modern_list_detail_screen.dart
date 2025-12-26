import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/modern_theme.dart';
import '../../../../core/widgets/modern_widgets.dart';
import '../../../../data/models/grocery_list.dart';
import '../../../../data/providers/providers.dart';

/// Modern grocery list detail screen with fluid interactions.
class ModernListDetailScreen extends ConsumerStatefulWidget {
  final String listId;

  const ModernListDetailScreen({
    super.key,
    required this.listId,
  });

  @override
  ConsumerState<ModernListDetailScreen> createState() => _ModernListDetailScreenState();
}

class _ModernListDetailScreenState extends ConsumerState<ModernListDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(groceryListProvider(widget.listId).notifier).loadList();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > 80;
    if (shouldShow != _showAppBarTitle) {
      setState(() => _showAppBarTitle = shouldShow);
    }
  }

  Future<void> _addItem() async {
    HapticFeedback.mediumImpact();
    
    final item = await showModalBottomSheet<GroceryListItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddItemSheet(),
    );

    if (item != null) {
      await ref.read(groceryListProvider(widget.listId).notifier).addItem(item);
    }
  }

  Future<void> _renameList(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RenameSheet(controller: controller),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      await ref.read(groceryListProvider(widget.listId).notifier).updateName(newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groceryListProvider(widget.listId));
    final theme = Theme.of(context);

    final list = state.list;
    final items = list?.items ?? [];
    final checkedCount = items.where((i) => i.isChecked).length;
    final progress = items.isNotEmpty ? checkedCount / items.length : 0.0;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // App Bar
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: PressableScale(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            title: AnimatedOpacity(
              opacity: _showAppBarTitle ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Text(list?.name ?? ''),
            ),
            actions: [
              if (items.isNotEmpty)
                PressableScale(
                  onTap: () => context.push('/compare/${widget.listId}'),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: ModernTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.compare_arrows_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Compare',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // List name (tappable to edit)
                      GestureDetector(
                        onTap: () => _renameList(list?.name ?? ''),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                list?.name ?? 'Loading...',
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Progress row
                      Row(
                        children: [
                          Text(
                            '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (checkedCount > 0) ...[
                            Text(
                              ' • ',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '$checkedCount done',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: ModernTheme.emerald,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      // Progress bar
                      if (items.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(
                              progress == 1.0 ? ModernTheme.emerald : theme.colorScheme.primary,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Items
          if (state.isLoading && items.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.add_shopping_cart_rounded,
                title: 'No items yet',
                description: 'Add items to your list to start comparing prices',
                action: FilledButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverReorderableList(
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ReorderableDragStartListener(
                    key: ValueKey(item.id),
                    index: index,
                    child: StaggeredFadeIn(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ItemTile(
                          item: item,
                          onToggle: () => _toggleItem(item),
                          onDelete: () => _deleteItem(item),
                          onEdit: () => _editItem(item),
                        ),
                      ),
                    ),
                  );
                },
                itemCount: items.length,
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex < newIndex) newIndex--;
                  ref.read(groceryListProvider(widget.listId).notifier)
                      .reorderItems(oldIndex, newIndex);
                },
              ),
            ),
        ],
      ),
      floatingActionButton: PressableScale(
        onTap: _addItem,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: ModernTheme.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: ModernTheme.shadowColored(ModernTheme.emerald),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Add Item',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleItem(GroceryListItem item) {
    HapticFeedback.selectionClick();
    ref.read(groceryListProvider(widget.listId).notifier).toggleItem(item.id);
  }

  void _deleteItem(GroceryListItem item) {
    HapticFeedback.mediumImpact();
    ref.read(groceryListProvider(widget.listId).notifier).removeItem(item.id);
  }

  Future<void> _editItem(GroceryListItem item) async {
    final updatedItem = await showModalBottomSheet<GroceryListItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddItemSheet(existingItem: item),
    );

    if (updatedItem != null) {
      await ref.read(groceryListProvider(widget.listId).notifier).updateItem(updatedItem);
    }
  }
}

// ============================================================
// ITEM TILE
// ============================================================

class _ItemTile extends StatelessWidget {
  final GroceryListItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ItemTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: ModernTheme.rose,
          borderRadius: BorderRadius.circular(ModernTheme.radiusLg),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
        ),
      ),
      child: PressableScale(
        onTap: onToggle,
        onLongPress: onEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(ModernTheme.space4),
          decoration: BoxDecoration(
            color: item.isChecked
                ? theme.colorScheme.surfaceContainerLow
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(ModernTheme.radiusLg),
            border: Border.all(
              color: item.isChecked
                  ? Colors.transparent
                  : theme.colorScheme.outlineVariant.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Checkbox
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: item.isChecked
                      ? ModernTheme.emerald
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: item.isChecked
                        ? ModernTheme.emerald
                        : theme.colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: item.isChecked
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              
              // Item info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        decoration: item.isChecked
                            ? TextDecoration.lineThrough
                            : null,
                        color: item.isChecked
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.notes!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              
              // Quantity badge
              if (item.quantity > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'x${item.quantity}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ADD ITEM SHEET
// ============================================================

class _AddItemSheet extends StatefulWidget {
  final GroceryListItem? existingItem;

  const _AddItemSheet({this.existingItem});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late int _quantity;
  bool _hasName = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingItem?.name ?? '');
    _notesController = TextEditingController(text: widget.existingItem?.notes ?? '');
    _quantity = widget.existingItem?.quantity ?? 1;
    _hasName = _nameController.text.trim().isNotEmpty;
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    setState(() {
      _hasName = _nameController.text.trim().isNotEmpty;
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final item = GroceryListItem(
      id: widget.existingItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      quantity: _quantity,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      isChecked: widget.existingItem?.isChecked ?? false,
      position: widget.existingItem?.position ?? 0,
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.existingItem != null;

    return Container(
      margin: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(ModernTheme.radius2xl),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ModernTheme.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: ModernTheme.space5),
              
              // Title
              Text(
                isEditing ? 'Edit Item' : 'Add Item',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ModernTheme.space5),
              
              // Name input
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Item name',
                  hintText: 'Milk, Bread, Eggs...',
                  prefixIcon: const Icon(Icons.shopping_bag_outlined),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: ModernTheme.space4),
              
              // Notes input
              TextField(
                controller: _notesController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Brand preference, size...',
                  prefixIcon: const Icon(Icons.notes_outlined),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                ),
              ),
              const SizedBox(height: ModernTheme.space4),
              
              // Quantity
              Row(
                children: [
                  Text(
                    'Quantity',
                    style: theme.textTheme.titleSmall,
                  ),
                  const Spacer(),
                  PressableScale(
                    onTap: _quantity > 1
                        ? () {
                            HapticFeedback.selectionClick();
                            setState(() => _quantity--);
                          }
                        : null,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _quantity > 1
                            ? theme.colorScheme.surfaceContainerHighest
                            : theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.remove,
                        color: _quantity > 1
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '$_quantity',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  PressableScale(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _quantity++);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ModernTheme.space6),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: ModernTheme.space3),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _hasName ? _submit : null,
                      child: Text(isEditing ? 'Save' : 'Add'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// RENAME SHEET
// ============================================================

class _RenameSheet extends StatefulWidget {
  final TextEditingController controller;

  const _RenameSheet({required this.controller});

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {
      _hasText = widget.controller.text.trim().isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(ModernTheme.radius2xl),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ModernTheme.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: ModernTheme.space5),
              
              Text(
                'Rename List',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ModernTheme.space5),
              
              TextField(
                controller: widget.controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'List name',
                  prefixIcon: const Icon(Icons.edit_outlined),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerLow,
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.pop(context, value.trim());
                  }
                },
              ),
              const SizedBox(height: ModernTheme.space5),
              
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: ModernTheme.space3),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _hasText
                          ? () => Navigator.pop(context, widget.controller.text.trim())
                          : null,
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
