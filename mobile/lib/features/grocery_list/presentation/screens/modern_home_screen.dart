import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/modern_theme.dart';
import '../../../../core/widgets/modern_widgets.dart';
import '../../../../data/models/grocery_list.dart';
import '../../../../data/providers/providers.dart';

/// Modern home screen with beautiful list cards.
class ModernHomeScreen extends ConsumerStatefulWidget {
  const ModernHomeScreen({super.key});

  @override
  ConsumerState<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends ConsumerState<ModernHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(groceryListsProvider.notifier).loadLists();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > 60;
    if (shouldShow != _showAppBarTitle) {
      setState(() {
        _showAppBarTitle = shouldShow;
      });
    }
  }

  Future<void> _createNewList() async {
    HapticFeedback.mediumImpact();
    
    final controller = TextEditingController();
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateListSheet(controller: controller),
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
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // App Bar
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: theme.scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            title: AnimatedOpacity(
              opacity: _showAppBarTitle ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Text('My Lists'),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings_outlined, size: 22),
                ),
                onPressed: () => context.push('/settings'),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Lists',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${state.lists.length} ${state.lists.length == 1 ? 'list' : 'lists'}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Refresh indicator
          SliverToBoxAdapter(
            child: RefreshIndicator(
              onRefresh: () => ref.read(groceryListsProvider.notifier).loadLists(),
              child: const SizedBox.shrink(),
            ),
          ),

          // Content
          if (state.isLoading && state.lists.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.lists.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.shopping_basket_outlined,
                title: 'No grocery lists yet',
                description: 'Create your first list to start comparing prices across stores',
                action: FilledButton.icon(
                  onPressed: _createNewList,
                  icon: const Icon(Icons.add),
                  label: const Text('Create List'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final list = state.lists[index];
                    return StaggeredFadeIn(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ModernListCard(
                          list: list,
                          onTap: () => context.push('/list/${list.id}'),
                          onCompare: () => context.push('/compare/${list.id}'),
                          onDelete: () => _confirmDelete(list),
                        ),
                      ),
                    );
                  },
                  childCount: state.lists.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: state.lists.isNotEmpty
          ? PressableScale(
              onTap: _createNewList,
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
                      'New List',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _confirmDelete(GroceryList list) async {
    HapticFeedback.mediumImpact();
    
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _DeleteConfirmSheet(listName: list.name),
    );

    if (confirmed == true) {
      ref.read(groceryListsProvider.notifier).deleteList(list.id);
    }
  }
}

// ============================================================
// MODERN LIST CARD
// ============================================================

class _ModernListCard extends StatelessWidget {
  final GroceryList list;
  final VoidCallback onTap;
  final VoidCallback onCompare;
  final VoidCallback onDelete;

  const _ModernListCard({
    required this.list,
    required this.onTap,
    required this.onCompare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemCount = list.items.length;
    final checkedCount = list.items.where((i) => i.isChecked).length;
    final progress = itemCount > 0 ? checkedCount / itemCount : 0.0;

    return PressableScale(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(ModernTheme.radiusXl),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: ModernTheme.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(ModernTheme.space4),
              child: Row(
                children: [
                  // Icon badge
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: _getGradientForList(list),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: ModernTheme.space4),
                  
                  // List info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.checklist_rounded,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                              style: theme.textTheme.bodySmall?.copyWith(
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
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: ModernTheme.emerald,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Arrow
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            
            // Progress bar
            if (itemCount > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ModernTheme.space4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      progress == 1.0 ? ModernTheme.emerald : theme.colorScheme.primary,
                    ),
                    minHeight: 4,
                  ),
                ),
              ),
            ],
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(ModernTheme.space3),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.compare_arrows_rounded,
                      label: 'Compare',
                      color: ModernTheme.sky,
                      onTap: onCompare,
                    ),
                  ),
                  const SizedBox(width: ModernTheme.space2),
                  _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: '',
                    color: ModernTheme.rose,
                    onTap: onDelete,
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getGradientForList(GroceryList list) {
    // Rotate through different gradients based on list name hash
    final hash = list.name.hashCode.abs() % 4;
    switch (hash) {
      case 0:
        return ModernTheme.primaryGradient;
      case 1:
        return ModernTheme.coolGradient;
      case 2:
        return ModernTheme.warmGradient;
      default:
        return LinearGradient(
          colors: [ModernTheme.violet, ModernTheme.rose],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}

// ============================================================
// ACTION BUTTON
// ============================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(icon, size: 18, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CREATE LIST SHEET
// ============================================================

class _CreateListSheet extends StatefulWidget {
  final TextEditingController controller;

  const _CreateListSheet({required this.controller});

  @override
  State<_CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends State<_CreateListSheet> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
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
                'Create New List',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ModernTheme.space5),
              
              // Input
              TextField(
                controller: widget.controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Weekly groceries, Party supplies...',
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
                      onPressed: _hasText
                          ? () => Navigator.pop(context, widget.controller.text.trim())
                          : null,
                      child: const Text('Create'),
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
// DELETE CONFIRM SHEET
// ============================================================

class _DeleteConfirmSheet extends StatelessWidget {
  final String listName;

  const _DeleteConfirmSheet({required this.listName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: ModernTheme.rose.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 32,
                  color: ModernTheme.rose,
                ),
              ),
              const SizedBox(height: ModernTheme.space4),
              
              Text(
                'Delete List?',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: ModernTheme.space2),
              
              Text(
                'Are you sure you want to delete "$listName"? This cannot be undone.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ModernTheme.space5),
              
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: ModernTheme.space3),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(context, true);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: ModernTheme.rose,
                      ),
                      child: const Text('Delete'),
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
