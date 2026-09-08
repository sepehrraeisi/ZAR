import 'package:flutter/material.dart';

/// Displays an exact, already-formatted amount and its unit as one stable
/// visual block. The unit is intentionally the first child of an LTR row so
/// it stays physically to the left of the number inside an RTL screen.
class ZarAmountDisplay extends StatelessWidget {
  const ZarAmountDisplay({
    super.key,
    required this.amount,
    required this.unit,
    this.amountStyle,
    this.unitStyle,
    this.purity,
    this.negative = false,
  });

  final String amount;
  final String unit;
  final TextStyle? amountStyle;
  final TextStyle? unitStyle;
  final String? purity;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayedAmount = negative && !amount.startsWith('-')
        ? '-$amount'
        : amount;
    final resolvedAmountStyle = amountStyle ?? theme.textTheme.bodyMedium;
    final resolvedUnitStyle = unitStyle ?? theme.textTheme.bodyMedium;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    unit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolvedUnitStyle,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    displayedAmount,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolvedAmountStyle,
                  ),
                ],
              ),
            ),
            if (purity != null)
              Text(
                purity!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
