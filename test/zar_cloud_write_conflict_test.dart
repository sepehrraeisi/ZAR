import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/zar_domain_repository.dart';

void main() {
  test('stale and terminal conflicts require an explicit reload', () {
    expect(
      const ZarCloudWriteConflictException.staleRevision(
        collection: 'zar_people',
        recordId: 'p1',
        currentRevision: 2,
      ).needsReload,
      isTrue,
    );
    expect(
      const ZarCloudWriteConflictException.lifecycleLocked(
        collection: 'zar_deals',
        recordId: 'd1',
      ).needsReload,
      isTrue,
    );
    expect(
      const ZarCloudWriteConflictException.terminalFieldLocked(
        collection: 'zar_settlements',
        recordId: 's1',
      ).needsReload,
      isTrue,
    );
    expect(
      const ZarCloudWriteConflictException.idempotencyMismatch(
        collection: 'zar_people',
        recordId: 'p1',
      ).needsReload,
      isTrue,
    );
  });

  test('generic cash conflicts do not advertise reload by default', () {
    expect(
      const ZarCloudWriteConflictException(
        code: 'cash_entry_immutable',
        collection: 'zar_cash_entries',
        recordId: 'c1',
      ).needsReload,
      isFalse,
    );
  });

  test('stale revision message hints at same-account multi-device', () {
    const conflict = ZarCloudWriteConflictException.staleRevision(
      collection: 'zar_settlements',
      recordId: 's1',
      currentRevision: 4,
    );
    expect(conflict.message, contains('همین حساب'));
    expect(conflict.message, contains('تازه کنید'));
  });
}
