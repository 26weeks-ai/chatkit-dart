/// Base class for ChatKit related failures.
class ChatKitException implements Exception {
  ChatKitException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ChatKitException($message${cause != null ? ', cause: $cause' : ''})';
}

/// Thrown when the server responds with an error payload.
class ChatKitServerException extends ChatKitException {
  ChatKitServerException(
    super.message, {
    super.cause,
    this.statusCode,
    this.error,
  });

  final int? statusCode;
  final Map<String, Object?>? error;
}

/// Indicates that an operation cannot be performed while a response is streaming.
class ChatKitStreamingInProgressException extends ChatKitException {
  ChatKitStreamingInProgressException(String message) : super(message);
}

/// Raised when the API configuration is invalid.
class ChatKitConfigurationException extends ChatKitException {
  ChatKitConfigurationException(String message) : super(message);
}

