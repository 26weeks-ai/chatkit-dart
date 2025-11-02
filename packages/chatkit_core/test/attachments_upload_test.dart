import 'dart:collection';
import 'dart:convert';

import 'package:chatkit_core/chatkit_core.dart';
import 'package:chatkit_core/src/api/api_client.dart';
import 'package:chatkit_core/src/models/request.dart';
import 'package:chatkit_core/src/options.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

class _StubApiClient extends ChatKitApiClient {
  _StubApiClient(Queue<Map<String, Object?>> responses)
      : _responses = responses,
        super(apiConfig: const CustomApiConfig(url: 'https://chatkit.test'));

  final Queue<Map<String, Object?>> _responses;
  ChatKitRequest? lastRequest;

  @override
  Future<Map<String, Object?>> send(
    ChatKitRequest request, {
    Map<String, Object?> bodyOverrides = const {},
  }) async {
    lastRequest = request;
    if (_responses.isNotEmpty) {
      return _responses.removeFirst();
    }
    return const {};
  }
}

class _RecordingUploadClient extends http.BaseClient {
  _RecordingUploadClient({required this.response, this.statusCode = 200});

  final Map<String, Object?> response;
  final int statusCode;
  http.BaseRequest? lastRequest;
  Map<String, String>? recordedFields;
  Map<String, String>? recordedHeaders;
  List<int> recordedBytes = const [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    recordedHeaders = Map<String, String>.from(request.headers);
    if (request is http.MultipartRequest) {
      recordedFields = Map<String, String>.from(request.fields);
    }
    final bodyBytes = <int>[];
    await for (final chunk in request.finalize()) {
      bodyBytes.addAll(chunk);
    }
    recordedBytes = bodyBytes;
    final encoded = utf8.encode(jsonEncode(response));
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([encoded]),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('registerAttachment', () {
    test('performs two-phase upload with multipart fields', () async {
      final responses = Queue<Map<String, Object?>>.from([
        {
          'type': 'image',
          'id': 'att_123',
          'name': 'example.png',
          'mime_type': 'image/png',
          'upload_url': 'https://uploads.example.com/form',
          'upload_method': 'POST',
          'upload_fields': {'key': 'value1', 'policy': 'value2'},
          'upload_headers': {'x-extra': 'true'},
        },
      ]);
      final apiClient = _StubApiClient(responses);
      final uploadClient = _RecordingUploadClient(
        response: {
          'type': 'image',
          'id': 'att_123',
          'name': 'example.png',
          'mime_type': 'image/png',
          'upload_url': null,
        },
        statusCode: 201,
      );

      final controller = ChatKitController(
        ChatKitOptions(
          api: const CustomApiConfig(
            url: 'https://chatkit.test',
            uploadStrategy: TwoPhaseUploadStrategy(),
          ),
        ),
        apiClient: apiClient,
        uploadClient: uploadClient,
      );

      final progressTicks = <int>[];
      final attachment = await controller.registerAttachment(
        name: 'example.png',
        bytes: utf8.encode('image-bytes'),
        mimeType: 'image/png',
        onProgress: (sent, _) => progressTicks.add(sent),
      );

      expect(apiClient.lastRequest?.type, 'attachments.create');
      expect(uploadClient.lastRequest, isA<http.MultipartRequest>());
      final multipart = uploadClient.lastRequest as http.MultipartRequest;
      expect(multipart.method, 'POST');
      expect(multipart.url.toString(), 'https://uploads.example.com/form');
      expect(multipart.fields['key'], 'value1');
      expect(multipart.fields['policy'], 'value2');
      expect(multipart.headers['x-extra'], 'true');
      expect(attachment.uploadUrl, isNull);
      expect(attachment.id, 'att_123');
      expect(progressTicks, isNotEmpty);

      await controller.dispose();
    });
  });
}
