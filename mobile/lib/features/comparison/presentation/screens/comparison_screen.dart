import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
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

class _ComparisonScreenState extends ConsumerState<ComparisonScreen> {
  final _zipCodeController = TextEditingController();
  bool _showBreakdown = false;

  @override
  void initState() {
    super.initState();
    _zipCodeController.text = ref.read(zipCodeProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runComparison();
    });
  }

  @override
  void dispose() {
    _zipCodeController.dispose();
    super.dispose();
  }

  Future<void> _runComparison() async {
    final zipCode = _zipCodeController.text.trim();
    if (zipCode.isEmpty) return;

    ref.read(zipCodeProvider.notifier).state = zipCode;

    await ref.read(comparisonProvider.notifier).comparePrices(
          listId: int.parse(widget.listId),
          zipCode: zipCode,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(comparisonProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Comparison'),
      ),
      body: Column(
        children: [
          // ZIP code input
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _zipCodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ZIP Code',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      hintText: 'Enter ZIP code',
                    ),
                    onSubmitted: (_) => _runComparison(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: state.isLoading ? null : _runComparison,
                  icon: const Icon(Icons.search),
                  label: const Text('Compare'),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _buildResults(state, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ComparisonState state, ThemeData theme) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
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

    return CustomScrollView(
      slivers: [
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

        // Store totals
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Store Totals',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final storeTotal = result.storeTotals[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: StoreTotalCard(storeTotal: storeTotal),
              );
            },
            childCount: result.storeTotals.length,
          ),
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
                      _showBreakdown
                          ? Icons.expand_less
                          : Icons.expand_more,
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
