import '../app_core.dart';

class ZarCsvExport {
  const ZarCsvExport();

  String encode({
    required List<AppRecord> records,
    required String Function(String personId) personName,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(_row(const [
      'شناسه',
      'نوع رکورد',
      'عملیات',
      'شخص',
      'مقدار',
      'دارایی',
      'کد ارز',
      'تاریخ شمسی',
      'ساعت',
      'وضعیت',
      'توضیحات',
    ]));

    for (final record in records) {
      buffer.writeln(_row([
        record.id,
        record.type == RecordType.deal ? 'معامله' : 'تسویه/تعهد',
        record.operationLabel,
        personName(record.personId),
        record.amountDisplay,
        record.assetLabel,
        record.currencyCode ?? '',
        '${record.date.year}/${record.date.month.toString().padLeft(2, '0')}/${record.date.day.toString().padLeft(2, '0')}',
        record.time == null
            ? ''
            : '${record.time!.hour.toString().padLeft(2, '0')}:${record.time!.minute.toString().padLeft(2, '0')}',
        record.statusLabel(),
        record.note ?? '',
      ]));
    }

    // UTF-8 BOM improves Persian rendering when opened directly in Excel.
    return '\uFEFF${buffer.toString()}';
  }

  String _row(List<String> values) => values.map(_escape).join(',');

  String _escape(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n') || escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }
}
