import '../../app_core.dart';
import 'notification_center.dart';

/// Builds notification text from the user's privacy preference.
///
/// This policy is shared by the in-app Notification Center and the future
/// native iOS/Android scheduler so lock-screen text cannot accidentally expose
/// more detail than the selected privacy level.
class ZarNotificationContent {
  const ZarNotificationContent({required this.title, required this.body});

  final String title;
  final String body;
}

class ZarNotificationContentPolicy {
  const ZarNotificationContentPolicy();

  ZarNotificationContent forRecord({
    required AppRecord record,
    required String personName,
    required NotificationPrivacy privacy,
  }) {
    switch (privacy) {
      case NotificationPrivacy.full:
        return ZarNotificationContent(
          title: '${record.operationLabel} • $personName',
          body: '${record.assetLabel} • ${record.amountDisplay}',
        );
      case NotificationPrivacy.limited:
        return ZarNotificationContent(
          title: 'یادآوری ${record.operationLabel}',
          body: '${record.operationLabel} برای $personName',
        );
      case NotificationPrivacy.private:
        return const ZarNotificationContent(
          title: 'یادآوری ZAR+',
          body: 'یک یادآوری کاری دارید.',
        );
    }
  }
}
