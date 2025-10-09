import 'dart:async';

import 'package:chatkit_core/chatkit_core.dart';
import 'package:chatkit_core/src/api/api_client.dart';
import 'package:test/test.dart';

class _NoopApiClient extends ChatKitApiClient {
  _NoopApiClient()
      : super(
          apiConfig: const CustomApiConfig(url: 'https://example.com/chatkit'),
        );

  @override
  Future<Map<String, Object?>> send(
    ChatKitRequest request, {
    Map<String, Object?> bodyOverrides = const {},
  }) async {
    return const {};
  }

  @override
  Future<void> sendStreaming(
    ChatKitRequest request, {
    required StreamEventCallback onEvent,
    void Function()? onDone,
    void Function(Object error, StackTrace stackTrace)? onError,
    Duration? keepAliveTimeout,
    void Function()? onKeepAliveTimeout,
    void Function(Duration duration)? onRetrySuggested,
    Map<String, Object?> bodyOverrides = const {},
  }) async {}
}

class _FailingApiClient extends ChatKitApiClient {
  _FailingApiClient(this.statusCode)
      : super(
          apiConfig: const CustomApiConfig(url: 'https://example.com/chatkit'),
        );

  final int statusCode;

  @override
  Future<Map<String, Object?>> send(
    ChatKitRequest request, {
    Map<String, Object?> bodyOverrides = const {},
  }) async {
    throw ChatKitServerException(
      'failure',
      statusCode: statusCode,
      error: const {'code': 'auth_expired'},
    );
  }
}

void main() {
  test('stale client notice triggers handshake and restores composer',
      () async {
    var staleCalls = 0;
    final controller = ChatKitController(
      ChatKitOptions(
        api: const CustomApiConfig(url: 'https://example.com/chatkit'),
        hostedHooks: HostedHooksOption(
          onStaleClient: () => staleCalls += 1,
        ),
      ),
      apiClient: _NoopApiClient(),
    );

    final events = <ChatKitEvent>[];
    final sub = controller.events.listen(events.add);

    controller.debugHandleStreamEvent(
      NoticeEvent(
        message: 'client stale',
        level: 'warning',
        code: 'stale_client',
        data: const {},
        title: null,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      events.whereType<ChatKitNoticeEvent>().map((event) => event.code),
      contains('stale_client'),
    );
    final availabilityEvents =
        events.whereType<ChatKitComposerAvailabilityEvent>().toList();
    expect(availabilityEvents, isNotEmpty);
    expect(availabilityEvents.first.available, isFalse);
    expect(availabilityEvents.last.available, isTrue);
    expect(staleCalls, 1);

    await sub.cancel();
    await controller.dispose();
  });

  test('auth expiry hook invoked on 401 and restored after refreshing',
      () async {
    var expiredCalls = 0;
    var restoredCalls = 0;
    final controller = ChatKitController(
      ChatKitOptions(
        api: const CustomApiConfig(url: 'https://example.com/chatkit'),
        hostedHooks: HostedHooksOption(
          onAuthExpired: () => expiredCalls += 1,
          onAuthRestored: () => restoredCalls += 1,
        ),
      ),
      apiClient: _FailingApiClient(401),
    );

    await expectLater(
      controller.listThreads(),
      throwsA(isA<ChatKitServerException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(expiredCalls, 1);
    expect(restoredCalls, 0);

    controller.debugHandleStreamEvent(
      NoticeEvent(
        message: 'client stale',
        level: 'warning',
        code: 'stale_client',
        data: const {},
        title: null,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(restoredCalls, 1);

    await controller.dispose();
  });
}
