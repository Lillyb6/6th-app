import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sixthapp/cloud_api.dart';

const testPhoto =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEklEQVR4nGPo2H23Y/ddBggFADo6CIFrmVhZAAAAAElFTkSuQmCC';

class TestCloudApi extends CloudApi {
  TestCloudApi() : super('test-token');
  final posts = <Map<String, dynamic>>[];
  Map<String, dynamic> profile = {
    'id': 1,
    'name': 'Sky',
    'bio': '',
    'avatar': '',
  };
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    calls.add(path);
    if (path == '/profile' && data == null) return profile;
    if (path == '/profile') {
      profile = {...profile, ...data!};
      return profile;
    }
    if (path == '/posts') {
      posts.insert(0, {
        'id': posts.length + 1,
        'user_id': 1,
        'name': profile['name'],
        'avatar': profile['avatar'],
        'caption': data!['caption'],
        'location': data['location'],
        'image': data['image'],
        'best': data['best'] == true ? 1 : 0,
        'liked': 0,
        'like_count': 0,
        'created_at': 1700000000,
      });
      return {'id': posts.first['id']};
    }
    if (path.endsWith('/like')) {
      final post = posts.firstWhere(
        (p) => p['id'].toString() == path.split('/')[2],
      );
      post['liked'] = data!['liked'] == true ? 1 : 0;
      post['like_count'] = post['liked'];
      return {'liked': data['liked'], 'likes': post['like_count']};
    }
    if (path.endsWith('/best')) {
      posts.firstWhere(
        (p) => p['id'].toString() == path.split('/')[2],
      )['best'] = data!['best'] == true
          ? 1
          : 0;
      return {};
    }
    return {
      'posts': posts.map((p) => Map<String, dynamic>.from(p)).toList(),
      'next': null,
    };
  }
}

CloudApi failingApi() => CloudApi(
  'test-token',
  client: MockClient(
    (_) async =>
        http.Response(jsonEncode({'error': 'The sky is offline.'}), 503),
  ),
);
