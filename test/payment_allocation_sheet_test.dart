import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/application/customer_operational_balance_projector.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_payment_allocation.dart';
import 'package:flutter_app/features/settlements/payment_allocation_sheet.dart';
import 'customer_operational_balance_projector_test.dart' as fixtures;

void main() {
  Widget host(Future<void> Function(List<ZarPaymentAllocation>) onSave) =>
      MaterialApp(
        home: Scaffold(
          body: PaymentAllocationSheet(
            source: fixtures.payment(ZarSettlementDirection.receive),
            initial: const [],
            targets: [
              ZarCustomerTomanObligation(
                targetType: ZarPaymentAllocationTarget.deal,
                targetId: 'deal',
                direction: ZarSettlementDirection.receive,
                originalToman: BigInt.from(2000000000),
                allocatedToman: BigInt.zero,
              ),
            ],
            targetLabel: (_) => 'فروش ارز',
            onSave: onSave,
          ),
        ),
      );
  testWidgets(
    'free receipt has no preselected amount and saves no allocation',
    (tester) async {
      List<ZarPaymentAllocation>? saved;
      await tester.pumpWidget(host((rows) async => saved = rows));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tester.tap(find.text('تأیید و ذخیره تخصیص'));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
    },
  );
  testWidgets(
    'explicit Persian amount survives failed write and remains retryable',
    (tester) async {
      List<ZarPaymentAllocation>? attempted;
      await tester.pumpWidget(
        host((rows) async {
          attempted = rows;
          throw StateError('disk');
        }),
      );
      await tester.enterText(find.byType(TextField), '۵۰۰۰۰۰۰۰۰');
      await tester.tap(find.text('تأیید و ذخیره تخصیص'));
      await tester.pumpAndSettle();
      expect(attempted!.single.amount.wholeTomans, 500000000);
      expect(attempted!.single.targetId, 'deal');
      expect(find.textContaining('تخصیص ذخیره نشد'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '۵۰۰٬۰۰۰٬۰۰۰',
      );
    },
  );
}
