import 'package:chatkit_core/chatkit_core.dart';
import 'package:test/test.dart';

void main() {
  group('ThreadStreamEvent', () {
    test('parses thread.created', () {
      final event = ThreadStreamEvent.fromJson({
        'type': 'thread.created',
        'thread': {
          'id': 'thr_123',
          'title': 'Sample',
          'created_at': '2024-01-01T00:00:00Z',
          'status': {'type': 'active'},
          'items': {
            'data': [],
            'after': null,
            'has_more': false,
          },
        },
      });

      expect(event, isA<ThreadCreatedEvent>());
      final created = event as ThreadCreatedEvent;
      expect(created.thread.metadata.id, 'thr_123');
      expect(created.thread.metadata.title, 'Sample');
    });

    test('falls back to unknown event', () {
      final event = ThreadStreamEvent.fromJson({'type': 'mystery'});
      expect(event, isA<UnknownStreamEvent>());
    });
  });
}
