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
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Text('وضعیت مالی', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
        ],
        Text(
          'باید دریافت کنم: ${ZarAmountFormatter.toman(balance.receivableToman)}',
        ),
        const SizedBox(height: 6),
        Text(
          'باید پرداخت کنم: ${ZarAmountFormatter.toman(balance.payableToman)}',
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
}
