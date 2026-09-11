import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/application/customer_operational_balance_projector.dart';
import 'package:flutter_app/features/people/operational_people_screen.dart';
import 'package:flutter_app/domain/zar_domain_models.dart';
import 'package:flutter_app/domain/zar_payment_allocation.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('fa', 'IR'),
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

void main() {
  testWidgets(
    'people cards surface identity, counts, balance and last activity',
    (tester) async {
      final person = AppPerson(id: 'p1', name: 'مهیار', phone: '۰۹۱۲۱۲۳۴۵۶۷');
      final record = AppRecord(
        id: 'd1',
        type: RecordType.deal,
        operationLabel: 'خرید',
        personId: person.id,
        amountDisplay: '۱۰٬۰۰۰',
        assetLabel: 'ارز',
        date: Jalali(1405, 6, 18),
        time: const TimeOfDay(hour: 16, minute: 13),
      );

      await tester.pumpWidget(
        _host(
          OperationalPeopleScreen(
            people: [person],
            records: [record],
            archivedCount: 0,
            onAddPerson: () {},
            onOpenPerson: (_) {},
            onOpenArchive: () {},
            balanceFor: (_) => ZarCustomerOperationalBalance([
              ZarCustomerTomanObligation(
                targetType: ZarPaymentAllocationTarget.deal,
                targetId: record.id,
                direction: ZarSettlementDirection.deliver,
                originalToman: BigInt.from(500000000),
                allocatedToman: BigInt.zero,
              ),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مهیار'), findsOneWidget);
      expect(find.text('۰۹۱۲۱۲۳۴۵۶۷'), findsOneWidget);
      expect(find.text('۱ معامله'), findsOneWidget);
      expect(find.text('۰ تعهد باز'), findsOneWidget);
      expect(find.text('به او باید بدهم'), findsOneWidget);
      expect(find.textContaining('آخرین فعالیت: خرید'), findsOneWidget);
    },
  );
}
