import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../data/models/comparison.dart';

/// Card showing a store's total price.
class StoreTotalCard extends StatelessWidget {
  /// The store total to display.
  final StoreTotalComparison storeTotal;

  const StoreTotalCard({
    super.key,
    required this.storeTotal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      color: storeTotal.isCheapest
          ? theme.colorScheme.primaryContainer
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            storeTotal.storeName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: storeTotal.isCheapest
                                  ? theme.colorScheme.onPrimaryContainer
                                  : null,
                            ),
                          ),
                          if (storeTotal.isCheapest) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'BEST',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        storeTotal.storeChain,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: storeTotal.isCheapest
                              ? theme.colorScheme.onPrimaryContainer
                                  .withAlpha(179)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (storeTotal.storeAddress != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          storeTotal.storeAddress!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: storeTotal.isCheapest
                                ? theme.colorScheme.onPrimaryContainer
                                    .withAlpha(179)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.formatCurrency(storeTotal.totalPrice),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: storeTotal.isCheapest
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      'total',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: storeTotal.isCheapest
                            ? theme.colorScheme.onPrimaryContainer.withAlpha(179)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStat(
                  context,
                  Icons.check_circle_outline,
                  '${storeTotal.itemsFound} items',
                  storeTotal.isCheapest,
                ),
                const SizedBox(width: 16),
                if (storeTotal.itemsOnSale > 0)
                  _buildStat(
                    context,
                    Icons.local_offer_outlined,
                    '${storeTotal.itemsOnSale} on sale',
                    storeTotal.isCheapest,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(
    BuildContext context,
    IconData icon,
    String text,
    bool isPrimary,
  ) {
    final theme = Theme.of(context);
    final color = isPrimary
        ? theme.colorScheme.onPrimaryContainer.withAlpha(179)
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
