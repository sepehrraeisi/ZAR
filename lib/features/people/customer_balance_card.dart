import 'package:flutter/material.dart';
import '../../application/customer_operational_balance_projector.dart';
import '../../domain/zar_amount_formatter.dart';

class CustomerBalanceCard extends StatelessWidget {
  const CustomerBalanceCard({
    super.key,
    required this.balance,
    this.compact = false,
  });
  final ZarCustomerOperationalBalance balance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final receivable = ZarAmountFormatter.toman(balance.receivableToman);
    final payable = ZarAmountFormatter.toman(balance.payableToman);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Text('وضعیت مالی', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
        ],
        if (compact) ...[
          _compactLine('بستانکارم از او', receivable),
          const SizedBox(height: 6),
          _compactLine('بدهکارم به او', payable),
        ] else ...[
          _balanceTile(
            context,
            title: 'بستانکارم از او',
            subtitle: 'باید دریافت کنم',
            amount: receivable,
            color: const Color(0xFF2F6F73),
          ),
          const SizedBox(height: 8),
          _balanceTile(
            context,
            title: 'بدهکارم به او',
            subtitle: 'باید پرداخت کنم',
            amount: payable,
            color: const Color(0xFF9A6700),
          ),
        ],
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

  Widget _compactLine(String title, String amount) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              amount,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );

  Widget _balanceTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String amount,
    required Color color,
  }) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                amount,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      );
}
