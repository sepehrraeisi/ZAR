import 'package:flutter/material.dart';

import '../../application/customer_operational_balance_projector.dart';
import '../../domain/zar_amount_formatter.dart';
import '../../domain/zar_domain_models.dart';

class CustomerBalanceCard extends StatelessWidget {
  const CustomerBalanceCard({
    super.key,
    required this.balance,
    this.compact = false,
    this.onShareBucket,
  });

  final ZarCustomerOperationalBalance balance;
  final bool compact;
  final ValueChanged<ZarCustomerBalanceAssetBucket>? onShareBucket;

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
            'دریافت/پرداخت آزاد این مبالغ را کاهش نمی‌دهد.',
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
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(title)),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: buckets.isEmpty
                ? Text(
                    ZarAmountFormatter.toman(BigInt.zero),
                    textAlign: TextAlign.end,
                    style: TextStyle(color: color),
                  )
                : Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 4,
                    children: buckets
                        .take(2)
                        .map((bucket) => _compactBucket(bucket, color))
                        .toList(growable: false),
                  ),
          ),
          if (buckets.length > 2)
            Text(
              ' +${_toPersianDigits((buckets.length - 2).toString())} قلم',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
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
    final label = _bucketText(bucket);
    return Directionality(
      textDirection: bucket.assetType == ZarAssetType.currency
          ? TextDirection.ltr
          : TextDirection.rtl,
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
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
    final amount = _bucketAmount(bucket);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  identity,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    amount,
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (bucket.sourceCount > 1)
                  Text(
                    '${_toPersianDigits(bucket.sourceCount.toString())} رکورد',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (onShare != null)
            Semantics(
              button: true,
              label: 'اشتراک‌گذاری این مورد',
              child: IconButton(
                tooltip: 'اشتراک‌گذاری این مورد',
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_outlined, size: 19),
              ),
            ),
        ],
      ),
    );
  }

  String _bucketText(ZarCustomerBalanceAssetBucket bucket) {
    final amount = _formatDecimal(bucket.amount);
    return switch (bucket.assetType) {
      ZarAssetType.currency =>
        bucket.currencyCode == 'TOMAN'
            ? '$amount تومان'
            : '${bucket.currencyCode ?? ''} $amount',
      ZarAssetType.gold => '$amount گرم طلا',
      ZarAssetType.coin => '${bucket.displayName ?? 'سکه'} $amount عدد',
    };
  }

  String _bucketIdentity(ZarCustomerBalanceAssetBucket bucket) {
    return switch (bucket.assetType) {
      ZarAssetType.currency =>
        bucket.currencyCode == 'TOMAN'
            ? 'وجه نقد (تومان)'
            : 'ارز ${bucket.currencyCode ?? ''}',
      ZarAssetType.gold =>
        bucket.goldFineness == null
            ? 'طلای عیار نامشخص'
            : 'طلای عیار ${_toPersianDigits(bucket.goldFineness!)}',
      ZarAssetType.coin => bucket.displayName ?? 'سکه',
    };
  }

  String _bucketAmount(ZarCustomerBalanceAssetBucket bucket) {
    final value = _formatDecimal(bucket.amount);
    return switch (bucket.assetType) {
      ZarAssetType.currency => value,
      ZarAssetType.gold => '$value گرم',
      ZarAssetType.coin => '$value عدد',
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
