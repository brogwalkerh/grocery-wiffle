import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../data/models/comparison.dart';

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
    final theme = Theme.of(context);

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
                      item.cheapestPrice!.currentPrice * item.quantity,
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

    if (item.quantity != 1.0 || item.unit != null) {
      final qty = Formatters.formatQuantity(item.quantity);
      if (item.unit != null) {
        parts.add('$qty ${item.unit}');
      } else {
        parts.add('Qty: $qty');
      }
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
          final total = storePrice.currentPrice * item.quantity;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCheapest
                  ? theme.colorScheme.primaryContainer.withAlpha(77)
                  : theme.colorScheme.surfaceContainerHighest.withAlpha(77),
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
                      if (storePrice.isOnSale)
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
                            : null,
                      ),
                    ),
                    Text(
                      '${Formatters.formatCurrency(storePrice.currentPrice)}/ea',
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
}
