import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/comparison.dart';
import '../../../../data/models/store.dart';
import 'price_correction_sheet.dart';

/// Card showing a store's total price with expandable item breakdown.
class StoreTotalCard extends StatefulWidget {
  /// The store total to display.
  final StoreTotalComparison storeTotal;

  /// Item breakdown data for this store.
  final List<ItemPriceComparison>? itemBreakdown;

  /// Total items in the list (for showing completion status).
  final int? totalItems;

  /// Whether to visually indicate estimated prices.
  final bool hideEstimatedPrices;

  /// Callback when a price is corrected.
  final void Function(Map<String, dynamic> correction)? onPriceCorrected;

  const StoreTotalCard({
    super.key,
    required this.storeTotal,
    this.itemBreakdown,
    this.totalItems,
    this.hideEstimatedPrices = false,
    this.onPriceCorrected,
  });

  @override
  State<StoreTotalCard> createState() => _StoreTotalCardState();
}

class _StoreTotalCardState extends State<StoreTotalCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotationAnimation;

  // Track corrected prices locally
  final Map<String, double> _correctedPrices = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  /// Get items available at this store
  List<_StoreItemPrice> _getStoreItems() {
    if (widget.itemBreakdown == null) return [];

    final items = <_StoreItemPrice>[];
    for (final item in widget.itemBreakdown!) {
      // Find price at this store - try by storeId first, then by storeName
      StorePrice? priceAtStore;

      // Try matching by storeId
      for (final price in item.pricesByStore) {
        if (price.storeId == widget.storeTotal.storeId) {
          priceAtStore = price;
          break;
        }
      }

      // If no match by ID, try matching by store name (fallback for data inconsistencies)
      if (priceAtStore == null) {
        for (final price in item.pricesByStore) {
          if (price.storeName.toLowerCase() ==
                  widget.storeTotal.storeName.toLowerCase() ||
              price.storeChain.toLowerCase() ==
                  widget.storeTotal.storeChain.toLowerCase()) {
            priceAtStore = price;
            break;
          }
        }
      }

      if (priceAtStore != null) {
        if (widget.hideEstimatedPrices && priceAtStore.isEstimate) continue;
        items.add(_StoreItemPrice(
          itemName: item.itemName,
          quantity: item.quantity,
          price: priceAtStore,
        ));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasAllItems = widget.storeTotal.hasAllItems;
    final storeItems = _getStoreItems();
    final hasBreakdown = storeItems.isNotEmpty;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: widget.storeTotal.isCheapest
          ? colorScheme.primaryContainer
          : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.storeTotal.isCheapest
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.outlineVariant.withOpacity(0.5),
          width: widget.storeTotal.isCheapest ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main card content - tappable to expand
          InkWell(
            onTap: hasBreakdown ? _toggleExpanded : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store header row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: widget.storeTotal.isCheapest
                              ? colorScheme.primary.withOpacity(0.2)
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.store,
                          size: 22,
                          color: widget.storeTotal.isCheapest
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),

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
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: widget.storeTotal.isCheapest
                                          ? colorScheme.onPrimaryContainer
                                          : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.storeTotal.isCheapest) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'BEST',
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onPrimary,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.storeTotal.storeChain,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: widget.storeTotal.isCheapest
                                    ? colorScheme.onPrimaryContainer
                                        .withOpacity(0.7)
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Price column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Formatters.formatCurrency(
                                widget.storeTotal.totalPrice),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: widget.storeTotal.isCheapest
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.primary,
                            ),
                          ),
                          Text(
                            'total',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: widget.storeTotal.isCheapest
                                  ? colorScheme.onPrimaryContainer
                                      .withOpacity(0.7)
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Stats row with expand indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: widget.storeTotal.isCheapest
                          ? colorScheme.primary.withOpacity(0.1)
                          : colorScheme.surfaceContainerHighest
                              .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _buildStat(
                          context,
                          hasAllItems
                              ? Icons.check_circle
                              : Icons.shopping_bag_outlined,
                          widget.totalItems != null
                              ? '${widget.storeTotal.itemsFound}/${widget.totalItems}'
                              : '${widget.storeTotal.itemsFound}',
                          'items',
                          widget.storeTotal.isCheapest,
                          highlight: hasAllItems,
                        ),
                        if (widget.storeTotal.itemsOnSale > 0) ...[
                          _buildDivider(context),
                          _buildStat(
                            context,
                            Icons.local_offer_outlined,
                            '${widget.storeTotal.itemsOnSale}',
                            'on sale',
                            widget.storeTotal.isCheapest,
                            isOnSale: true,
                          ),
                        ],
                        if (widget.storeTotal.estimatedDriveTimeMinutes !=
                            null) ...[
                          _buildDivider(context),
                          _buildStat(
                            context,
                            Icons.drive_eta_outlined,
                            '${widget.storeTotal.estimatedDriveTimeMinutes}',
                            'min',
                            widget.storeTotal.isCheapest,
                          ),
                        ],
                        const Spacer(),
                        // Expand/collapse indicator
                        if (hasBreakdown)
                          RotationTransition(
                            turns: _rotationAnimation,
                            child: Icon(
                              Icons.expand_more,
                              size: 20,
                              color: widget.storeTotal.isCheapest
                                  ? colorScheme.onPrimaryContainer
                                      .withOpacity(0.6)
                                  : colorScheme.onSurfaceVariant
                                      .withOpacity(0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable item breakdown
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Divider
                Divider(
                  height: 1,
                  thickness: 1,
                  color: widget.storeTotal.isCheapest
                      ? colorScheme.primary.withOpacity(0.15)
                      : colorScheme.outlineVariant.withOpacity(0.3),
                ),

                // Items header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Item Breakdown',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: widget.storeTotal.isCheapest
                          ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                          : colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Item list
                if (storeItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(
                      'No items found at this store',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ...storeItems.map((item) => _buildItemRow(context, item)),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, _StoreItemPrice item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final price = item.price;

    // Check for corrected price
    final correctionKey = '${item.itemName}_${widget.storeTotal.storeName}';
    final correctedPrice = _correctedPrices[correctionKey];
    final displayPrice = correctedPrice ?? price.currentPrice;
    final total = correctedPrice != null
        ? correctedPrice * item.quantity
        : (price.calculatedTotal ?? (price.currentPrice * item.quantity));
    final isEstimate = price.isEstimate && correctedPrice == null;
    final isOnSale = price.isOnSale;
    final wasCorrected = correctedPrice != null;

    return InkWell(
      onTap: () => _showPriceCorrection(context, item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isOnSale
              ? colorScheme.tertiary.withOpacity(0.08)
              : wasCorrected
                  ? colorScheme.primary.withOpacity(0.08)
                  : null,
        ),
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
                            color: widget.storeTotal.isCheapest
                                ? colorScheme.onPrimaryContainer
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOnSale) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiary,
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
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                      ],
                      if (isEstimate) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: colorScheme.estimated,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // Size/unit badge - more prominent
                      if (price.productSize != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.storeTotal.isCheapest
                                ? colorScheme.onPrimaryContainer
                                    .withOpacity(0.1)
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            price.productSize!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: widget.storeTotal.isCheapest
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Price info
                      Text(
                        '${item.quantity}× ${Formatters.formatCurrency(displayPrice)}'
                        '${price.unitPrice != null ? ' (${Formatters.formatCurrency(price.unitPrice!)}/ea)' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: widget.storeTotal.isCheapest
                              ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Price
            Text(
              Formatters.formatCurrency(total),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isOnSale
                    ? colorScheme.tertiary
                    : widget.storeTotal.isCheapest
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceCorrection(BuildContext context, _StoreItemPrice item) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PriceCorrectionSheet(
        itemName: item.itemName,
        storeName: widget.storeTotal.storeName,
        storeChain: widget.storeTotal.storeChain,
        currentPrice: item.price.currentPrice,
        productSize: item.price.productSize,
        isEstimate: item.price.isEstimate,
        storeId: widget.storeTotal.storeId,
      ),
    );

    if (result != null) {
      final correctionKey = '${item.itemName}_${widget.storeTotal.storeName}';
      setState(() {
        _correctedPrices[correctionKey] = result['new_price'] as double;
      });
      widget.onPriceCorrected?.call(result);
    }
  }

  Widget _buildDivider(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: widget.storeTotal.isCheapest
          ? theme.colorScheme.onPrimaryContainer.withOpacity(0.2)
          : theme.colorScheme.outline.withOpacity(0.2),
    );
  }

  Widget _buildStat(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    bool isPrimary, {
    bool highlight = false,
    bool isOnSale = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color color;

    if (isOnSale) {
      color = colorScheme.tertiary;
    } else if (highlight) {
      color = isPrimary ? colorScheme.onPrimaryContainer : colorScheme.primary;
    } else {
      color = isPrimary
          ? colorScheme.onPrimaryContainer.withOpacity(0.8)
          : colorScheme.onSurfaceVariant;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

/// Helper class to hold item + price at store
class _StoreItemPrice {
  final String itemName;
  final int quantity;
  final StorePrice price;

  const _StoreItemPrice({
    required this.itemName,
    required this.quantity,
    required this.price,
  });
}
