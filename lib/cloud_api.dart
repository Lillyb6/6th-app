import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;

import 'auth_api.dart';

class CloudPhoto {
  CloudPhoto(Map<String, dynamic> d)
    : id = d['id'] as int,
      userId = d['user_id'].toString(),
      name = d['name'] as String,
      image = d['image'] as String,
      avatar = d['avatar'] as String? ?? '',
      caption = d['caption'] as String,
      location = d['location'] as String,
      best = d['best'] == 1,
      liked = d['liked'] == 1,
      likes = d['like_count'] as int,
      createdAt = DateTime.fromMillisecondsSinceEpoch(
        (d['created_at'] as int) * 1000,
      );
  final int id;
  final String userId;
  final String name, image, avatar, caption, location;
  bool best, liked;
  int likes;
  final DateTime createdAt;
}

Uint8List photoBytes(String data) => base64Decode(data.split(',').last);

Future<String?> choosePhoto() async {
  const group = XTypeGroup(
    label: 'Photos',
    extensions: ['jpg', 'jpeg', 'png', 'webp'],
    mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
    uniformTypeIdentifiers: [
      'public.jpeg',
      'public.png',
      'org.webmproject.webp',
    ],
  );
  final file = await openFile(acceptedTypeGroups: [group]);
  if (file == null) return null;
  if (await file.length() > 5000000) {
    throw const AuthException('Choose a photo under 5 MB.');
  }
  final bytes = await file.readAsBytes();
  String? type;
  if (bytes.length > 12) {
    if (bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255) {
      type = 'jpeg';
    } else if (bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78) {
      type = 'png';
    } else if (ascii.decode(bytes.sublist(0, 4), allowInvalid: true) ==
            'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      type = 'webp';
    }
  }
  if (type == null) {
    throw const AuthException('Choose a JPEG, PNG or WebP photo.');
  }
  return 'data:image/$type;base64,${base64Encode(bytes)}';
}

class CloudApi {
  CloudApi(this.token, {http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://127.0.0.1:8000',
          );
  final String token, _baseUrl;
  final http.Client _client;

  Future<Map<String, dynamic>> guessCloud(String dataUrl) async {
    throw const AuthException('Cloud guesses are not available right now.');
  }

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final response =
          await (data == null
                  ? _client.get(uri, headers: headers)
                  : _client.post(uri, headers: headers, body: jsonEncode(data)))
              .timeout(const Duration(seconds: 30));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw AuthException(
          body['error'] as String? ?? 'Something went wrong. Please try again.',
        );
      }
      return body;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Could not reach Cloud Club. Please try again.',
      );
    }
  }

  void close() => _client.close();
}
