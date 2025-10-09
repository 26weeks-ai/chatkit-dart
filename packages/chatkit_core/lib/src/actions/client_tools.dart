import 'dart:async';

/// Describes an invocation of a client tool originating from the server.
class ChatKitClientToolInvocation {
  const ChatKitClientToolInvocation({
    required this.name,
    required this.params,
    required this.threadId,
    required this.invocationId,
  });

  final String name;
  final Map<String, Object?> params;
  final String threadId;
  final String invocationId;
}

typedef ChatKitClientToolHandler = FutureOr<Map<String, Object?>> Function(
  ChatKitClientToolInvocation invocation,
);

/// A payload returned back to the server indicating the client tool failed.
class ClientToolErrorResult implements Exception {
  ClientToolErrorResult({
    required this.message,
    this.details,
  });

  final String message;
  final Map<String, Object?>? details;

  Map<String, Object?> toJson() => {
        'type': 'error',
        'message': message,
        if (details != null) 'details': details,
      };
}

/// A payload returned back to the server when the client tool succeeds.
class ClientToolSuccessResult {
  ClientToolSuccessResult({
    required this.data,
  });

  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {
        'type': 'success',
        'data': data,
      };
}

/// Converts the handler result into a canonical map for transmission.
Map<String, Object?> normalizeClientToolResult(Object? result) {
  if (result == null) {
    return const {'type': 'success', 'data': {}};
  }
  if (result is ClientToolSuccessResult) {
    return result.toJson();
  }
  if (result is ClientToolErrorResult) {
    return result.toJson();
  }
  if (result is Map<String, Object?>) {
    return {
      'type': 'success',
      'data': result,
    };
  }
  throw ArgumentError(
    'Client tool handlers must return a Map, ClientToolSuccessResult, or '
    'ClientToolErrorResult. Received ${result.runtimeType}.',
  );
}
