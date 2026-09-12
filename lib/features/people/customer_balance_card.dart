import 'package:flutter/material.dart';

import '../../application/customer_operational_balance_projector.dart';
import '../../domain/zar_domain_models.dart';
import '../../widgets/zar_amount_display.dart';

class CustomerBalanceCard extends StatelessWidget {
  const CustomerBalanceCard({
    super.key,
    required this.balance,
    this.compact = false,
    this.onShareBucket,
    this.onTapBucket,
  });

  final ZarCustomerOperationalBalance balance;
  final bool compact;
  final ValueChanged<ZarCustomerBalanceAssetBucket>? onShareBucket;
  final ValueChanged<ZarCustomerBalanceAssetBucket>? onTapBucket;

  @override
  Widget build(BuildContext context) {
    final receivable = _withToman(
      balance.receivableAssetBuckets,
      direction: ZarSettlementDirection.receive,
      amount: balance.receivableToman,
    );
    final payable = _withToman(
      balance.payableAssetBuckets,
      direction: ZarSettlementDirection.deliver,
      amount: balance.payableToman,
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Text(
            'وضعیت مالی با این شخص',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
        ],
        _directionSection(
          context,
          title: compact ? 'از او باید بگیرم' : 'باید از او بگیرم',
          buckets: receivable,
          color: const Color(0xFF2F6F73),
          compact: compact,
        ),
        SizedBox(height: compact ? 6 : 10),
        _directionSection(
          context,
          title: compact ? 'به او باید بدهم' : 'باید به او بدهم',
          buckets: payable,
          color: const Color(0xFF9A6700),
          compact: compact,
        ),
        if (!compact) ...[
          const SizedBox(height: 8),
          Text(
            'مانده از معاملات و دریافت/پرداخت‌های انجام‌شده محاسبه می‌شود.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
    if (compact) return content;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }

  List<ZarCustomerBalanceAssetBucket> _withToman(
    List<ZarCustomerBalanceAssetBucket> buckets, {
    required ZarSettlementDirection direction,
    required BigInt amount,
  }) {
    if (amount == BigInt.zero ||
        buckets.any(
          (item) => item.assetType == ZarAssetType.currency && item.isToman,
        )) {
      return buckets;
    }
    return [
      ...buckets,
      ZarCustomerBalanceAssetBucket(
        direction: direction,
        assetType: ZarAssetType.currency,
        currencyCode: 'TOMAN',
        amount: amount.toString(),
      ),
    ];
  }

  Widget _directionSection(
    BuildContext context, {
    required String title,
    required List<ZarCustomerBalanceAssetBucket> buckets,
    required Color color,
    required bool compact,
  }) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (buckets.length > 2)
                Text(
                  '+${_toPersianDigits((buckets.length - 2).toString())} قلم',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 5),
          if (buckets.isEmpty)
            Text('موردی ندارد', style: TextStyle(color: color))
          else
            Wrap(
              alignment: WrapAlignment.start,
              spacing: 10,
              runSpacing: 4,
              children: buckets
                  .take(2)
                  .map((bucket) => _compactBucket(bucket, color))
                  .toList(growable: false),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 7),
        if (buckets.isEmpty)
          Text(
            'موردی وجود ندارد.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ...buckets.map(
            (bucket) => _bucketRow(
              context,
              bucket,
              color,
              onShare: onShareBucket == null
                  ? null
                  : () => onShareBucket!(bucket),
            ),
          ),
      ],
    );
  }

  Widget _compactBucket(ZarCustomerBalanceAssetBucket bucket, Color color) {
    final parts = _bucketDisplayParts(bucket);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Column(
        // The compact bucket lives in the RTL page context. `start` is the
        // physical right edge, keeping identity/value blocks anchored.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bucket.assetType != ZarAssetType.currency)
            Text(
              _bucketIdentity(bucket),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ZarAmountDisplay(
            amount: parts.amount,
            unit: parts.unit,
            purity: parts.purity,
            amountStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
            unitStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _bucketRow(
    BuildContext context,
    ZarCustomerBalanceAssetBucket bucket,
    Color color, {
    VoidCallback? onShare,
  }) {
    final identity = _bucketIdentity(bucket);
    final parts = _bucketDisplayParts(bucket);
    final card = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: onShare == null
                ? null
                : Semantics(
                    button: true,
                    label: 'اشتراک‌گذاری این مورد',
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      tooltip: 'اشتراک‌گذاری این مورد',
                      onPressed: onShare,
                      icon: const Icon(Icons.ios_share_outlined, size: 19),
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 132,
            child: ZarAmountDisplay(
              amount: parts.amount,
              unit: parts.unit,
              purity: parts.purity,
              amountStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
              unitStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                // In RTL, start is the physical right edge. Using end here
                // caused the identity column to drift toward the center.
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identity,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (bucket.sourceCount > 1)
                    Text(
                      '${_toPersianDigits(bucket.sourceCount.toString())} رکورد',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (onTapBucket == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onTapBucket!(bucket),
      child: card,
    );
  }

  String _bucketIdentity(ZarCustomerBalanceAssetBucket bucket) {
    return switch (bucket.assetType) {
      ZarAssetType.currency =>
        bucket.currencyCode == 'TOMAN' ? 'وجه نقد' : 'ارز',
      ZarAssetType.gold =>
        bucket.goldFineness == null
            ? 'طلای عیار نامشخص'
            : 'طلای عیار ${_toPersianDigits(bucket.goldFineness!)}',
      ZarAssetType.coin => bucket.displayName ?? 'سکه',
    };
  }

  ({String amount, String unit, String? purity}) _bucketDisplayParts(
    ZarCustomerBalanceAssetBucket bucket,
  ) {
    final amount = _formatDecimal(bucket.amount);
    return switch (bucket.assetType) {
      ZarAssetType.currency => (
        amount: amount,
        unit: bucket.currencyCode == 'TOMAN'
            ? 'تومان'
            : bucket.currencyCode ?? 'ارز',
        purity: null,
      ),
      ZarAssetType.gold => (amount: amount, unit: 'گرم طلا', purity: null),
      ZarAssetType.coin => (amount: amount, unit: 'عدد', purity: null),
    };
  }

  String _formatDecimal(String input) {
    final parts = input.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '٬',
    );
    final value = parts.length == 1 ? whole : '$whole٫${parts[1]}';
    return _toPersianDigits(value);
  }
}

String _toPersianDigits(String input) {
  const latin = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  var value = input;
  for (var i = 0; i < latin.length; i++) {
    value = value.replaceAll(latin[i], persian[i]);
  }
  return value;
}
