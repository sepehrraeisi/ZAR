import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/pocketbase/zar_pocketbase_sse.dart';

void main() {
  test('parser assembles frames across chunk boundaries', () {
    final parser = ZarPocketBaseSseParser();
    expect(parser.add('event: PB_CONN'), isEmpty);
    expect(parser.add('ECT\ndata: {"clientId":"abc"}\n\n'), [
      isA<ZarPocketBaseSseEvent>()
          .having((e) => e.event, 'event', 'PB_CONNECT')
          .having((e) => e.data, 'data', '{"clientId":"abc"}'),
    ]);
  });

  test('parser ignores comments and keeps multi-line data', () {
    final parser = ZarPocketBaseSseParser();
    final events = parser.add(
      ': keep-alive\n'
      'event: zar_workspaces/w1\n'
      'data: {"action":"update"}\n'
      'data: {"epoch":3}\n'
      '\n',
    );
    expect(events, hasLength(1));
    expect(events.single.event, 'zar_workspaces/w1');
    expect(events.single.data, '{"action":"update"}\n{"epoch":3}');
  });
}
