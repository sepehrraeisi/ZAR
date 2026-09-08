import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  group('AppPerson archive lifecycle', () {
    test('archive preserves identity and contact data', () {
      final person = AppPerson(
        id: 'p-test',
        name: 'علی رضایی',
        phone: '۰۹۱۲۱۲۳۴۵۶۷',
        note: 'مشتری ثابت',
      );

      final archived = person.copyWith(archived: true);

      expect(archived.id, person.id);
      expect(archived.name, person.name);
      expect(archived.phone, person.phone);
      expect(archived.note, person.note);
      expect(archived.archived, isTrue);
    });

    test('archived person can be restored without losing data', () {
      final archived = AppPerson(
        id: 'p-test',
        name: 'رضا محمدی',
        phone: '۰۹۱۲۴۴۴۵۵۶۶',
        archived: true,
      );

      final restored = archived.copyWith(archived: false);

      expect(restored.archived, isFalse);
      expect(restored.id, archived.id);
      expect(restored.phone, archived.phone);
    });
  });

  group('Currency behavior', () {
    test('required currencies remain available by stable code', () {
      const expected = {'USD', 'EUR', 'AED', 'TRY', 'GBP', 'CAD', 'OTHER'};
      expect(kCurrencyOptions.map((e) => e.code).toSet(), expected);
    });

    test('currency formatting keeps conventional LTR value format', () {
      expect(formatCurrencyAmount('10000', 'USD'), r'$10,000');
      expect(formatCurrencyAmount('5000', 'EUR'), '€5,000');
      expect(formatCurrencyAmount('20000', 'AED'), 'AED 20,000');
      expect(formatCurrencyAmount('10000', 'TRY'), '₺10,000');
      expect(formatCurrencyAmount('5000', 'GBP'), '£5,000');
      expect(formatCurrencyAmount('10000', 'CAD'), 'CAD 10,000');
    });
  });

  group('Record semantics', () {
    test('only receive/deliver settlements are obligations', () {
      final receive = AppRecord(
        id: 's1',
        type: RecordType.settlement,
        operationLabel: 'دریافت',
        personId: 'p1',
        amountDisplay: '۲۵۰',
        assetLabel: 'گرم طلا',
        date: Jalali(1405, 6, 5),
      );
      final buy = AppRecord(
        id: 'd1',
        type: RecordType.deal,
        operationLabel: 'خرید',
        personId: 'p1',
        amountDisplay: '۲۵۰',
        assetLabel: 'گرم طلا',
        date: Jalali(1405, 6, 5),
      );

      expect(receive.isObligation, isTrue);
      expect(buy.isObligation, isFalse);
    });
  });
}
