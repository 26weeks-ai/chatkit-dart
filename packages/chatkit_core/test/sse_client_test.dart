import 'dart:convert';
import 'dart:io';

import 'package:chatkit_core/src/api/sse_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'fixtures/streaming_fixture.dart';

void main() {
  test('SseClient forwards retry hints and yields decoded messages', () async {
    final client = SseClient();
    final received = <SseMessage>[];
    final retryHints = <Duration>[];
    final errors = <Object>[];

    await client.post(
      Uri.parse('https://example.com/chatkit'),
      body: const <String, Object?>{},
      onMessage: (message) async {
        received.add(message);
      },
      onRetrySuggested: (duration) => retryHints.add(duration),
      onError: (error, stackTrace) {
        errors.add(error);
      },
      sendOverride: (request) async {
        final raw = streamingFixtureAsSse();
        final chunks = raw
            .split('\n')
            .map((line) => utf8.encode('$line\n'))
            .toList(growable: false);
        return http.StreamedResponse(
          Stream<List<int>>.fromIterable(chunks),
          200,
          request: request,
          headers: {
            HttpHeaders.contentTypeHeader: 'text/event-stream',
          },
        );
      },
    );

    expect(errors, isEmpty);
    expect(retryHints, isNotEmpty);
    expect(retryHints.first, const Duration(milliseconds: 2500));

    final messagesWithPayload = received
        .where((message) => message.data != null && message.data!.isNotEmpty)
        .toList();
    final fixture = streamingFixtureEvents();
    expect(messagesWithPayload.length, fixture.length);

    for (var i = 0; i < fixture.length; i++) {
      final decoded = jsonDecode(messagesWithPayload[i].data!) as Map;
      expect(decoded['type'], fixture[i]['type']);
    }
  });
}
