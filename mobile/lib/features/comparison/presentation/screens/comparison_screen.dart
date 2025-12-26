import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/providers/providers.dart';
import '../widgets/store_total_card.dart';
import '../widgets/item_breakdown_list.dart';

/// Screen showing price comparison results.
class ComparisonScreen extends ConsumerStatefulWidget {
  /// The list ID to compare.
  final String listId;

  const ComparisonScreen({
    super.key,
    required this.listId,
  });

  @override
  ConsumerState<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends ConsumerState<ComparisonScreen>
    with SingleTickerProviderStateMixin {
  final _zipCodeController = TextEditingController();
  bool _showBreakdown = false;
  bool _showOnlyCompleteStores =
      false; // Default OFF: show all stores even if missing items
  bool _hideEstimatedPrices = true; // Default: hide estimated prices
  int _searchRadiusMiles = 10;
  bool _filtersExpanded = false;

  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;

  static const List<int> _radiusOptions = [1, 3, 5, 10, 25];

  @override
  void initState() {
    super.initState();
    _zipCodeController.text = ref.read(zipCodeProvider);
    _filterAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _filterAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runComparison();
    });
  }

  @override
  void dispose() {
    _zipCodeController.dispose();
    _filterAnimationController.dispose();
    super.dispose();
  }

  Future<void> _runComparison() async {
    final zipCode = _zipCodeController.text.trim();
    if (zipCode.isEmpty) return;

    ref.read(zipCodeProvider.notifier).state = zipCode;

    await ref.read(comparisonProvider.notifier).comparePrices(
          listId: widget.listId,
          zipCode: zipCode,
          radiusMiles: _searchRadiusMiles,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(comparisonProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            // Modern header with search
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button and title row
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price Comparison',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
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

          // Search row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _zipCodeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'ZIP Code',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    hintText: 'Enter ZIP code',
                    suffixIcon: _zipCodeController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              setState(() {
                                _zipCodeController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _runComparison(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: state.isLoading ? null : _runComparison,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                child: state.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Filter toggle row
          Row(
            children: [
              // Expand filters button
              Material(
                color: _filtersExpanded
                    ? theme.colorScheme.primary.withOpacity(0.12)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _filtersExpanded = !_filtersExpanded;
                      if (_filtersExpanded) {
                        _filterAnimationController.forward();
                      } else {
                        _filterAnimationController.reverse();
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune,
                          size: 16,
                          color: _filtersExpanded
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Filters',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _filtersExpanded
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: _filtersExpanded
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _filtersExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                          color: _filtersExpanded
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterToggle(
                label: 'Hide estimates',
                value: _hideEstimatedPrices,
                onChanged: (value) {
                  setState(() {
                    _hideEstimatedPrices = value;
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildFilterToggle(
                label: 'Full lists only',
                value: _showOnlyCompleteStores,
                onChanged: (value) {
                  setState(() {
                    _showOnlyCompleteStores = value;
                  });
                },
              ),
            ],
          ),

          // Expandable filter options
          SizeTransition(
            sizeFactor: _filterAnimation,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search radius selector
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Radius:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _radiusOptions.map((miles) {
                              final isSelected =
                                  miles == _searchRadiusMiles;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text('$miles mi'),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _searchRadiusMiles = miles;
                                      });
                                      if (_zipCodeController.text.isNotEmpty) {
                                        _runComparison();
                                      }
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _buildFilterToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: value
          ? theme.colorScheme.primary.withOpacity(0.12)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: value
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: value
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(ComparisonState state, ThemeData theme) {
    // Check if API is configured
    final isApiConfigured = ref.watch(isApiConfiguredProvider);

    if (!isApiConfigured) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.key_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'API Configuration Required',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'To search for real grocery prices, you need to configure API keys.\n\n'
                '1. Go to developer.kroger.com\n'
                '2. Create a free account\n'
                '3. Register an app to get Client ID & Secret\n'
                '4. Add them to lib/core/config/grocery_api_config.dart',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (state.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              if (state.progressMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.progressMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                'Comparison failed',
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
                onPressed: _runComparison,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final result = state.result;
    if (result == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.compare_arrows,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Enter a ZIP code to compare prices',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    // Check if we found any prices at all
    final hasAnyPrices = result.storeTotals.isNotEmpty;
    final itemsWithPrices = result.itemBreakdown
        .where((item) => item.pricesByStore.isNotEmpty)
        .length;
    final totalItems = result.itemBreakdown.length;
    final hasPartialResults =
        itemsWithPrices < totalItems && itemsWithPrices > 0;

    // Count estimated vs real prices in results
    int estimatedCount = 0;
    int realCount = 0;
    for (final item in result.itemBreakdown) {
      for (final price in item.pricesByStore) {
        if (price.isEstimate) {
          estimatedCount++;
        } else {
          realCount++;
        }
      }
    }
    final hasEstimates = estimatedCount > 0;

    if (!hasAnyPrices) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No prices found',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'We couldn\'t find prices for your items right now.\n'
                'Store websites may be temporarily unavailable.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _runComparison,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Partial results warning banner
        if (hasPartialResults)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Found prices for $itemsWithPrices of $totalItems items',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Savings banner
        if (result.potentialSavings > 0)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.savings_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Potential Savings',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          Formatters.formatCurrency(result.potentialSavings),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Store totals header with filter
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Store Totals',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${result.totalItems} items • ${result.completeStores.length} stores have all${hasEstimates && !_hideEstimatedPrices ? ' • Tap store for details' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Estimated prices info banner
        if (hasEstimates && !_hideEstimatedPrices)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: theme.colorScheme.estimated,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Some prices are estimated',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$estimatedCount estimated, $realCount from store ads',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _hideEstimatedPrices = true;
                      });
                    },
                    icon: const Icon(Icons.visibility_off, size: 16),
                    label: const Text('Hide'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Filtered store list
        Builder(
          builder: (context) {
            var filteredStores = result.storeTotals.toList();
            final totalItems = result.totalItems;

            // Calculate real (non-estimated) item counts per store
            final Map<int, int> realItemCounts = {};
            for (final store in filteredStores) {
              int realCount = 0;
              for (final item in result.itemBreakdown) {
                for (final price in item.pricesByStore) {
                  if (price.storeId == store.storeId && !price.isEstimate) {
                    realCount++;
                    break; // Found a real price for this item at this store
                  }
                }
              }
              realItemCounts[store.storeId] = realCount;
            }

            // Apply filters
            if (_hideEstimatedPrices) {
              // Filter out stores with no real prices
              filteredStores = filteredStores.where((store) {
                return (realItemCounts[store.storeId] ?? 0) > 0;
              }).toList();
            }

            if (_showOnlyCompleteStores) {
              if (_hideEstimatedPrices) {
                // When hiding estimates, "complete" means all items have REAL prices
                filteredStores = filteredStores.where((store) {
                  return (realItemCounts[store.storeId] ?? 0) >= totalItems;
                }).toList();
              } else {
                // Normal complete stores filter (includes estimates)
                filteredStores =
                    filteredStores.where((store) => store.hasAllItems).toList();
              }
            }

            if (filteredStores.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.store_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _showOnlyCompleteStores
                            ? 'No stores have all ${result.totalItems} items'
                            : _hideEstimatedPrices
                                ? 'No stores have real (non-estimated) prices'
                                : 'No stores found',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_showOnlyCompleteStores || _hideEstimatedPrices) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showOnlyCompleteStores = false;
                              _hideEstimatedPrices = false;
                            });
                          },
                          child: const Text('Clear filters'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final storeTotal = filteredStores[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: StoreTotalCard(
                      storeTotal: storeTotal,
                      itemBreakdown: result.itemBreakdown,
                      totalItems: result.totalItems,
                      hideEstimatedPrices: _hideEstimatedPrices,
                    ),
                  );
                },
                childCount: filteredStores.length,
              ),
            );
          },
        ),

        // Item breakdown toggle
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _showBreakdown = !_showBreakdown;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Item Breakdown',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      _showBreakdown ? Icons.expand_less : Icons.expand_more,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Item breakdown list
        if (_showBreakdown)
          SliverToBoxAdapter(
            child: ItemBreakdownList(items: result.itemBreakdown),
          ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
      ],
    );
  }
}
