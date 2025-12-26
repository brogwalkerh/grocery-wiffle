import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../data/models/comparison.dart';
import '../../../../data/models/store.dart';

/// List showing item-by-item price breakdown.
class ItemBreakdownList extends StatelessWidget {
  /// The items to display.
  final List<ItemPriceComparison> items;

  const ItemBreakdownList({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: items.map((item) => _ItemBreakdownTile(item: item)).toList(),
      ),
    );
  }
}

class _ItemBreakdownTile extends StatefulWidget {
  final ItemPriceComparison item;

  const _ItemBreakdownTile({required this.item});

  @override
  State<_ItemBreakdownTile> createState() => _ItemBreakdownTileState();
}

class _ItemBreakdownTileState extends State<_ItemBreakdownTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            title: Text(
              item.itemName,
              style: theme.textTheme.bodyLarge,
            ),
            subtitle: _buildSubtitle(theme),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.cheapestPrice != null)
                  Text(
                    Formatters.formatCurrency(
                      // Use the pre-calculated total which accounts for unit conversions
                      item.cheapestPrice!.calculatedTotal ?? 
                        (item.cheapestPrice!.currentPrice * item.quantity),
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
          if (_isExpanded) _buildExpandedContent(theme),
        ],
      ),
    );
  }

  Widget? _buildSubtitle(ThemeData theme) {
    final item = widget.item;
    final parts = <String>[];

    if (item.quantity != 1) {
      parts.add('Qty: ${item.quantity}');
    }

    if (item.matchConfidence < 100) {
      parts.add('${item.matchConfidence.toStringAsFixed(0)}% match');
    }

    if (parts.isEmpty) {
      return null;
    }

    return Text(
      parts.join(' • '),
      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildExpandedContent(ThemeData theme) {
    final item = widget.item;

    if (item.pricesByStore.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Text(
          'No price data available',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: item.pricesByStore.map((storePrice) {
          final isCheapest = storePrice.storeId == item.cheapestStoreId;
          // Use calculatedTotal for unit-aware pricing
          final total = storePrice.calculatedTotal ?? 
              (storePrice.currentPrice * item.quantity);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCheapest
                  ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                  : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: isCheapest
                  ? Border.all(
                      color: theme.colorScheme.primary,
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            storePrice.storeName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight:
                                  isCheapest ? FontWeight.w600 : null,
                            ),
                          ),
                          if (isCheapest) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      if (storePrice.isEstimate)
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Estimated',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        )
                      else if (storePrice.isOnSale)
                        Row(
                          children: [
                            Icon(
                              Icons.local_offer,
                              size: 14,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'On Sale',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.tertiary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.formatCurrency(total),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isCheapest
                            ? theme.colorScheme.primary
                            : storePrice.isEstimate
                                ? theme.colorScheme.outline
                                : null,
                      ),
                    ),
                    Text(
                      _formatUnitPrice(storePrice),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Format the unit price display based on product size
  String _formatUnitPrice(StorePrice storePrice) {
    final price = Formatters.formatCurrency(storePrice.currentPrice);
    final size = storePrice.productSize;
    
    if (size == null || size.isEmpty) {
      return '$price/ea';
    }
    
    // Check if it's a per-pound price (common for produce)
    final sizeLower = size.toLowerCase();
    if (sizeLower.contains('/lb') || sizeLower.contains('per lb') || 
        sizeLower.contains('per pound') || sizeLower == 'lb') {
      return '$price/lb';
    }
    
    // Check for other common units
    if (sizeLower.contains('/oz') || sizeLower.contains('per oz')) {
      return '$price/oz';
    }
    
    // Show the size if it's a specific quantity
    return '$price ($size)';
  }
}
