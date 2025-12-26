import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/comparison.dart';
import '../../../../data/models/store.dart';
import 'price_correction_sheet.dart';

/// Bottom sheet showing detailed breakdown of items at a specific store.
class StoreDetailSheet extends StatefulWidget {
  /// The store total info.
  final StoreTotalComparison storeTotal;

  /// Items with prices at this store.
  final List<ItemPriceComparison> itemBreakdown;

  /// Whether to hide estimated prices.
  final bool hideEstimatedPrices;

  /// Callback when a price is corrected.
  final void Function(Map<String, dynamic> correction)? onPriceCorrected;

  const StoreDetailSheet({
    super.key,
    required this.storeTotal,
    required this.itemBreakdown,
    this.hideEstimatedPrices = false,
    this.onPriceCorrected,
  });

  @override
  State<StoreDetailSheet> createState() => _StoreDetailSheetState();
}

class _StoreDetailSheetState extends State<StoreDetailSheet> {
  // Track corrected prices locally
  final Map<String, double> _correctedPrices = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Get prices for this store
    final storeItems = widget.itemBreakdown.where((item) {
      final priceAtStore = item.pricesByStore.cast<StorePrice?>().firstWhere(
            (p) => p?.storeId == widget.storeTotal.storeId,
            orElse: () => null,
          );
      if (priceAtStore == null) return false;
      if (widget.hideEstimatedPrices && priceAtStore.isEstimate) return false;
      return true;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Store header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    // Store icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: widget.storeTotal.isCheapest
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.store,
                        size: 28,
                        color: widget.storeTotal.isCheapest
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Store info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.storeTotal.storeName,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.storeTotal.isCheapest) ...[
                                const SizedBox(width: 8),
                                _buildBadge(
                                  context,
                                  'BEST PRICE',
                                  theme.colorScheme.primary,
                                  theme.colorScheme.onPrimary,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.storeTotal.storeChain,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (widget.storeTotal.storeAddress != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.storeTotal.storeAddress!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Total price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Formatters.formatCurrency(
                              widget.storeTotal.totalPrice),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          'total',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Stats row
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      context,
                      Icons.shopping_bag_outlined,
                      '${widget.storeTotal.itemsFound}',
                      'items found',
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                    _buildStatItem(
                      context,
                      Icons.local_offer_outlined,
                      '${widget.storeTotal.itemsOnSale}',
                      'on sale',
                    ),
                    if (widget.storeTotal.estimatedDriveTimeMinutes !=
                        null) ...[
                      Container(
                        width: 1,
                        height: 32,
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                      _buildStatItem(
                        context,
                        Icons.drive_eta_outlined,
                        '${widget.storeTotal.estimatedDriveTimeMinutes}',
                        'min drive',
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Items section header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Items',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${storeItems.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Items list
              Expanded(
                child: storeItems.isEmpty
                    ? Center(
                        child: Text(
                          'No items available at this store',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: storeItems.length,
                        itemBuilder: (context, index) {
                          final item = storeItems[index];
                          final priceAtStore = item.pricesByStore.firstWhere(
                            (p) => p.storeId == widget.storeTotal.storeId,
                          );
                          return _buildItemRow(context, item, priceAtStore);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge(
    BuildContext context,
    String text,
    Color background,
    Color foreground,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontSize: 10,
            ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(
    BuildContext context,
    ItemPriceComparison item,
    StorePrice price,
  ) {
    final theme = Theme.of(context);
    final customColors = theme.colorScheme;

    // Check if there's a corrected price
    final correctionKey = '${item.itemName}_${widget.storeTotal.storeName}';
    final correctedPrice = _correctedPrices[correctionKey];
    final displayPrice = correctedPrice ?? price.currentPrice;

    final total = correctedPrice != null
        ? correctedPrice * item.quantity
        : (price.calculatedTotal ?? (price.currentPrice * item.quantity));
    final isEstimate = price.isEstimate && correctedPrice == null;
    final isOnSale = price.isOnSale;
    final wasCorrected = correctedPrice != null;

    return GestureDetector(
      onTap: () => _showPriceCorrection(context, item, price),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isOnSale
              ? customColors.sale.withOpacity(0.08)
              : wasCorrected
                  ? theme.colorScheme.primaryContainer.withOpacity(0.2)
                  : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOnSale
                ? customColors.sale.withOpacity(0.3)
                : wasCorrected
                    ? theme.colorScheme.primary.withOpacity(0.3)
                    : theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Item info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.itemName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isOnSale) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: customColors.sale,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'SALE',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                            if (wasCorrected) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check,
                                      size: 10,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'UPDATED',
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (isEstimate) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: customColors.estimated,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.quantity}x at ${Formatters.formatCurrency(displayPrice)} each'
                          '${price.productSize != null ? ' • ${price.productSize}' : ''}'
                          '${isEstimate ? ' • Estimated' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.formatCurrency(total),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isOnSale ? customColors.sale : null,
                        ),
                      ),
                      if (isOnSale && price.savings > 0) ...[
                        Text(
                          'Save ${Formatters.formatCurrency(price.savings * item.quantity)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: customColors.savings,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // "Price wrong? Tap to update" hint
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(11),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 14,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isEstimate
                        ? 'Know the real price? Tap to update!'
                        : 'Price wrong? Tap to correct',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPriceCorrection(
    BuildContext context,
    ItemPriceComparison item,
    StorePrice price,
  ) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PriceCorrectionSheet(
        itemName: item.itemName,
        storeName: widget.storeTotal.storeName,
        storeChain: widget.storeTotal.storeChain,
        currentPrice: price.currentPrice,
        productSize: price.productSize,
        isEstimate: price.isEstimate,
        storeId: widget.storeTotal.storeId,
      ),
    );

    if (result != null) {
      // Store the corrected price locally
      final correctionKey = '${item.itemName}_${widget.storeTotal.storeName}';
      setState(() {
        _correctedPrices[correctionKey] = result['new_price'] as double;
      });

      // Notify parent if callback provided
      widget.onPriceCorrected?.call(result);

      // Show confirmation
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Price updated to ${Formatters.formatCurrency(result['new_price'])}',
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
