import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/notifications/record_tap_buffer.dart';

void main() {
  test('buffers a record tap until navigation handler is installed', () {
    final buffer = RecordTapBuffer();
    String? opened;

    buffer.add('settlement-1');
    expect(buffer.pendingRecordId, 'settlement-1');

    buffer.setHandler((id) => opened = id);

    expect(opened, 'settlement-1');
    expect(buffer.pendingRecordId, isNull);
  });

  test('delivers live taps immediately when handler is ready', () {
    final buffer = RecordTapBuffer();
    final opened = <String>[];
    buffer.setHandler(opened.add);

    buffer.add('s1');
    buffer.add('s2');

    expect(opened, ['s1', 's2']);
    expect(buffer.pendingRecordId, isNull);
  });

  test('only latest pre-bootstrap destination is retained', () {
    final buffer = RecordTapBuffer();
    String? opened;

    buffer.add('old');
    buffer.add('latest');
    buffer.setHandler((id) => opened = id);

    expect(opened, 'latest');
  });

  test('empty record ids are ignored', () {
    final buffer = RecordTapBuffer();

    buffer.add('');

    expect(buffer.pendingRecordId, isNull);
  });
}
