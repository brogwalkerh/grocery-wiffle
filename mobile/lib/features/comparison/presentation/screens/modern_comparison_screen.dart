import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;

import '../../../../core/theme/modern_theme.dart';
import '../../../../core/widgets/modern_widgets.dart';
import '../../../../data/models/comparison.dart';
import '../../../../data/models/store.dart';
import '../../../../data/providers/providers.dart';

/// Modern, fluid price comparison screen.
class ModernComparisonScreen extends ConsumerStatefulWidget {
  final String listId;

  const ModernComparisonScreen({
    super.key,
    required this.listId,
  });

  @override
  ConsumerState<ModernComparisonScreen> createState() =>
      _ModernComparisonScreenState();
}

class _ModernComparisonScreenState extends ConsumerState<ModernComparisonScreen>
    with TickerProviderStateMixin {
  final _zipController = TextEditingController();
  final _scrollController = ScrollController();

  bool _showFilters = false;
  bool _hideEstimates = true;
  bool _completeOnly = false;  // Default OFF - show all stores even if missing items
  int _searchRadiusMiles = 10;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _zipController.text = ref.read(zipCodeProvider);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runComparison();
    });
  }

  @override
  void dispose() {
    _zipController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runComparison() async {
    final zip = _zipController.text.trim();
    if (zip.isEmpty) return;

    HapticFeedback.mediumImpact();
    ref.read(zipCodeProvider.notifier).state = zip;

    _pulseController.repeat(reverse: true);

    await ref.read(comparisonProvider.notifier).comparePrices(
          listId: widget.listId,
          zipCode: zip,
          radiusMiles: _searchRadiusMiles,
        );

    _pulseController.stop();
    _pulseController.reset();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(comparisonProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(theme, state),

            // Results
            Expanded(
              child: _buildResults(state, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ComparisonState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            children: [
              PressableScale(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price Comparison',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Find the best deals near you',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Search bar
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _zipController,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Enter ZIP code',
                      prefixIcon: Icon(
                        Icons.location_on_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _runComparison(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PressableScale(
                onTap: state.isLoading ? null : _runComparison,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: state.isLoading ? _pulseAnimation.value : 1.0,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: ModernTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: state.isLoading
                              ? ModernTheme.shadowColored(ModernTheme.emerald)
                              : ModernTheme.shadowMd,
                        ),
                        child: state.isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.search_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  icon: Icons.tune,
                  label: 'Filters',
                  isSelected: _showFilters,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showFilters = !_showFilters);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  icon: Icons.verified_outlined,
                  label: 'Hide estimates',
                  isSelected: _hideEstimates,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _hideEstimates = !_hideEstimates);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  icon: Icons.check_circle_outline,
                  label: 'Complete only',
                  isSelected: _completeOnly,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _completeOnly = !_completeOnly);
                  },
                ),
              ],
            ),
          ),

          // Expanded filters
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildExpandedFilters(theme),
            ),
            crossFadeState: _showFilters
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedFilters(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.place_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Search radius',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [1, 3, 5, 10, 25].map((miles) {
            final isSelected = miles == _searchRadiusMiles;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PressableScale(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _searchRadiusMiles = miles);
                  if (_zipController.text.isNotEmpty) {
                    _runComparison();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$miles mi',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResults(ComparisonState state, ThemeData theme) {
    if (state.isLoading) {
      return _buildLoadingState(state, theme);
    }

    if (state.error != null) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        description: state.error!,
        iconColor: ModernTheme.rose,
        action: FilledButton.icon(
          onPressed: _runComparison,
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
        ),
      );
    }

    final result = state.result;
    if (result == null) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'Ready to compare',
        description:
            'Enter your ZIP code and tap search to find the best prices near you',
        iconColor: ModernTheme.sky,
      );
    }

    // Filter stores
    var stores = result.storeTotals.toList();
    final totalItems = result.itemBreakdown.length;

    // Calculate real (non-estimated) item counts and totals per store
    final Map<int, double> effectivePrices = {};
    final Map<int, int> realItemCounts = {};

    for (final store in stores) {
      double realTotal = 0;
      int realItemCount = 0;

      for (final item in result.itemBreakdown) {
        for (final price in item.pricesByStore) {
          if (price.storeId == store.storeId && !price.isEstimate) {
            realTotal += price.currentPrice * item.quantity;
            realItemCount++;
            break;
          }
        }
      }

      effectivePrices[store.storeId] = realTotal;
      realItemCounts[store.storeId] = realItemCount;
    }

    // Apply filters
    if (_hideEstimates) {
      // Filter out stores with no real prices
      stores =
          stores.where((s) => (realItemCounts[s.storeId] ?? 0) > 0).toList();
    }

    if (_completeOnly && totalItems > 0) {
      if (_hideEstimates) {
        // When hiding estimates, "complete" means all items have REAL prices
        stores = stores
            .where((s) => (realItemCounts[s.storeId] ?? 0) >= totalItems)
            .toList();
      } else {
        // Normal complete stores filter (includes estimates)
        stores = stores.where((s) => s.itemsFound >= totalItems).toList();
      }
    }

    if (stores.isEmpty) {
      return EmptyState(
        icon: Icons.store_mall_directory_outlined,
        title: 'No stores found',
        description: _hideEstimates
            ? 'No stores have real (non-estimated) prices. Try showing estimates.'
            : 'Try expanding your search radius or removing some filters',
        action: TextButton(
          onPressed: () {
            setState(() {
              _completeOnly = false;
              _hideEstimates = false;
            });
          },
          child: const Text('Clear Filters'),
        ),
      );
    }

    // Sort by price (use effective prices when hiding estimates)
    if (_hideEstimates) {
      stores.sort((a, b) => (effectivePrices[a.storeId] ?? double.infinity)
          .compareTo(effectivePrices[b.storeId] ?? double.infinity));
    } else {
      stores.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
    }

    final cheapestPrice = _hideEstimates
        ? (effectivePrices[stores.first.storeId] ?? stores.first.totalPrice)
        : stores.first.totalPrice;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Summary hero card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _SummaryHeroCard(
              cheapestStore: stores.first,
              totalStores: stores.length,
              potentialSavings: stores.length > 1
                  ? (_hideEstimates
                      ? (effectivePrices[stores.last.storeId] ??
                              stores.last.totalPrice) -
                          cheapestPrice
                      : stores.last.totalPrice - cheapestPrice)
                  : 0,
              effectivePrice:
                  _hideEstimates ? effectivePrices[stores.first.storeId] : null,
            ),
          ),
        ),

        // Section header
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'All Stores',
            subtitle: '${stores.length} stores found',
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          ),
        ),

        // Store cards
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final store = stores[index];
                final isWinner = index == 0;
                final storePrice = _hideEstimates
                    ? (effectivePrices[store.storeId] ?? store.totalPrice)
                    : store.totalPrice;
                final savings = storePrice - cheapestPrice;

                return StaggeredFadeIn(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _StoreCard(
                      store: store,
                      isWinner: isWinner,
                      rank: index + 1,
                      extraCost: savings,
                      itemBreakdown: result.itemBreakdown,
                      hideEstimates: _hideEstimates,
                      effectivePrice: _hideEstimates
                          ? effectivePrices[store.storeId]
                          : null,
                      realItemCount:
                          _hideEstimates ? realItemCounts[store.storeId] : null,
                    ),
                  ),
                );
              },
              childCount: stores.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(ComparisonState state, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated shopping cart
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -10 * math.sin(value * math.pi)),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: ModernTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: ModernTheme.shadowColored(ModernTheme.emerald),
                  ),
                  child: const Icon(
                    Icons.shopping_cart_outlined,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          Text(
            'Searching stores...',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          if (state.progressMessage != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                state.progressMessage!,
                key: ValueKey(state.progressMessage),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

          const SizedBox(height: 24),

          SizedBox(
            width: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                minHeight: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FILTER CHIP
// ============================================================

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.12)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SUMMARY HERO CARD
// ============================================================

class _SummaryHeroCard extends StatelessWidget {
  final StoreTotalComparison cheapestStore;
  final int totalStores;
  final double potentialSavings;
  final double? effectivePrice;

  const _SummaryHeroCard({
    required this.cheapestStore,
    required this.totalStores,
    required this.potentialSavings,
    this.effectivePrice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: ModernTheme.primaryGradient,
        borderRadius: BorderRadius.circular(ModernTheme.radius2xl),
        boxShadow: ModernTheme.shadowColored(ModernTheme.emerald),
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            right: -30,
            top: -30,
            child: Icon(
              Icons.local_offer_rounded,
              size: 150,
              color: Colors.white.withOpacity(0.1),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(ModernTheme.space5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Best Deal',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  cheapestStore.storeName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${(effectivePrice ?? cheapestStore.totalPrice).toStringAsFixed(2)}',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'total',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                if (potentialSavings > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.savings_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Save up to \$${potentialSavings.toStringAsFixed(2)} vs other stores',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STORE CARD
// ============================================================

class _StoreCard extends StatefulWidget {
  final StoreTotalComparison store;
  final bool isWinner;
  final int rank;
  final double extraCost;
  final List<ItemPriceComparison> itemBreakdown;
  final bool hideEstimates;
  final double? effectivePrice;
  final int? realItemCount;

  const _StoreCard({
    required this.store,
    required this.isWinner,
    required this.rank,
    required this.extraCost,
    required this.itemBreakdown,
    required this.hideEstimates,
    this.effectivePrice,
    this.realItemCount,
  });

  @override
  State<_StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends State<_StoreCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PressableScale(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _isExpanded = !_isExpanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(ModernTheme.radiusXl),
          border: Border.all(
            color: widget.isWinner
                ? ModernTheme.emerald.withOpacity(0.3)
                : theme.colorScheme.outlineVariant.withOpacity(0.5),
            width: widget.isWinner ? 2 : 1,
          ),
          boxShadow:
              widget.isWinner ? ModernTheme.shadowMd : ModernTheme.shadowSm,
        ),
        child: Column(
          children: [
            // Main row
            Padding(
              padding: const EdgeInsets.all(ModernTheme.space4),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.isWinner
                          ? ModernTheme.emerald
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: widget.isWinner
                          ? const Icon(
                              Icons.emoji_events_rounded,
                              size: 18,
                              color: Colors.white,
                            )
                          : Text(
                              '#${widget.rank}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Store info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.store.storeName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              widget.hideEstimates &&
                                      widget.realItemCount != null
                                  ? '${widget.realItemCount} items'
                                  : '${widget.store.itemsFound} items',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (widget.store.distanceMiles != null) ...[
                              Text(
                                ' • ',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '${widget.store.distanceMiles!.toStringAsFixed(1)} mi',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${(widget.effectivePrice ?? widget.store.totalPrice).toStringAsFixed(2)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: widget.isWinner
                              ? ModernTheme.emerald
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      if (widget.extraCost > 0)
                        Text(
                          '+\$${widget.extraCost.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ModernTheme.rose,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 8),

                  // Expand icon
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpandedContent(theme),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(ThemeData theme) {
    final items = _getItemsForStore();

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(ModernTheme.space4),
        child: Text(
          'No item details available',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: [
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
        Padding(
          padding: const EdgeInsets.all(ModernTheme.space3),
          child: Column(
            children: items.map((item) {
              final isEstimate = item.price?.isEstimate ?? false;
              if (widget.hideEstimates && isEstimate) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isEstimate)
                            Text(
                              'Estimated',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: ModernTheme.coral,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (item.price != null)
                      Text(
                        '\$${item.price!.currentPrice.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<_ItemWithPrice> _getItemsForStore() {
    final items = <_ItemWithPrice>[];

    for (final item in widget.itemBreakdown) {
      StorePrice? priceAtStore;
      for (final price in item.pricesByStore) {
        if (price.storeId == widget.store.storeId) {
          priceAtStore = price;
          break;
        }
      }

      items.add(_ItemWithPrice(
        name: item.itemName,
        quantity: item.quantity,
        price: priceAtStore,
      ));
    }

    return items;
  }
}

class _ItemWithPrice {
  final String name;
  final int quantity;
  final StorePrice? price;

  _ItemWithPrice({
    required this.name,
    required this.quantity,
    this.price,
  });
}
