import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:flutter_app/app_core.dart';
import 'package:flutter_app/features/notifications/notification_center.dart';
import 'package:flutter_app/features/notifications/notification_content_policy.dart';

void main() {
  final record = AppRecord(
    id: 's1',
    type: RecordType.settlement,
    operationLabel: 'تحویل',
    personId: 'p1',
    amountDisplay: r'$10,000',
    assetLabel: 'ارز',
    currencyCode: 'USD',
    date: Jalali(1405, 6, 5),
    time: const TimeOfDay(hour: 11, minute: 0),
  );
  const policy = ZarNotificationContentPolicy();

  test('full privacy includes person and amount', () {
    final content = policy.forRecord(
      record: record,
      personName: 'رضا محمدی',
      privacy: NotificationPrivacy.full,
    );

    expect(content.title, contains('رضا محمدی'));
    expect(content.body, contains(r'$10,000'));
  });

  test('limited privacy includes person but hides amount', () {
    final content = policy.forRecord(
      record: record,
      personName: 'رضا محمدی',
      privacy: NotificationPrivacy.limited,
    );

    expect(content.body, contains('رضا محمدی'));
    expect(content.body, isNot(contains(r'$10,000')));
  });

  test('private privacy hides person and amount', () {
    final content = policy.forRecord(
      record: record,
      personName: 'رضا محمدی',
      privacy: NotificationPrivacy.private,
    );

    expect(content.title, 'یادآوری ZAR+');
    expect(content.body, 'یک یادآوری کاری دارید.');
    expect(content.body, isNot(contains('رضا محمدی')));
    expect(content.body, isNot(contains(r'$10,000')));
  });
}
