import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'auth_api.dart';
import 'cloud_api.dart';

/// Cloud Club's hosted data adapter. Database access is guarded by the RLS
/// policies in supabase/cloud_club.sql; image bytes live in private Storage.
class SupabaseCloudApi extends CloudApi {
  SupabaseCloudApi(super.token);

  sb.SupabaseClient get _db => sb.Supabase.instance.client;
  static const _bucket = 'cloud-photos';

  @override
  Future<Map<String, dynamic>> guessCloud(String dataUrl) async {
    try {
      final comma = dataUrl.indexOf(',');
      final semicolon = dataUrl.indexOf(';');
      if (!dataUrl.startsWith('data:image/') || comma < 0 || semicolon < 0) {
        throw const AuthException('Choose a valid cloud photo first.');
      }
      final response = await _db.functions.invoke(
        'cloud-shape',
        body: {
          'imageBase64': dataUrl.substring(comma + 1),
          'mimeType': dataUrl.substring(5, semicolon),
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      throw const AuthException(
        'The cloud guessing service returned an invalid response.',
      );
    } on sb.FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['error'] is String) {
        if (details['status'] == 503) {
          throw const AuthException(
            'Gemini is temporarily busy. Please wait a moment and try again.',
          );
        }
        if (details['status'] == 429) {
          throw const AuthException(
            'Gemini has reached its usage limit. Please try again later.',
          );
        }
        throw AuthException(details['error'] as String);
      }
      throw const AuthException(
        'Could not get a cloud guess. Please try again.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Could not get a cloud guess. Please try again.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      if (path == '/profile' && data == null) return await _getProfile();
      if (path == '/profile' && data != null) return await _saveProfile(data);
      if (path == '/feed' || path.startsWith('/feed?')) {
        return await _getPosts(path, own: false);
      }
      if (path == '/profile/posts' || path.startsWith('/profile/posts?')) {
        return await _getPosts(path, own: true);
      }
      if (path == '/posts' && data != null) return await _createPost(data);
      final match = RegExp(r'^/posts/(\d+)/(like|best|delete)$')
          .firstMatch(path);
      if (match != null) {
        return await _postAction(
          int.parse(match.group(1)!),
          match.group(2)!,
          data ?? {},
        );
      }
      throw const AuthException('That Cloud Club action is not available.');
    } on AuthException {
      rethrow;
    } on sb.PostgrestException catch (error) {
      throw AuthException(error.message);
    } on sb.StorageException catch (error) {
      throw AuthException(error.message);
    } catch (_) {
      throw const AuthException(
        'Could not reach Cloud Club. Please try again.',
      );
    }
  }

  Future<Map<String, dynamic>> _getProfile() async {
    final user = _db.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    final row = await _db.from('profiles').select().eq('id', user.id).single();
    final avatarPath = _normalizeStoragePath(
      row['avatar_path'] as String? ?? '',
    );
    return {
      'id': user.id,
      'name': row['name'] as String,
      'bio': row['bio'] as String? ?? '',
      'avatar': avatarPath.isEmpty ? '' : await _signedImage(avatarPath),
    };
  }

  Future<Map<String, dynamic>> _saveProfile(Map<String, dynamic> data) async {
    final user = _db.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    final old = await _db
        .from('profiles')
        .select('avatar_path')
        .eq('id', user.id)
        .single();
    final previousPath = _normalizeStoragePath(
      old['avatar_path'] as String? ?? '',
    );
    final avatar = data['avatar'] as String? ?? '';
    var avatarPath = previousPath;
    if (avatar.isEmpty) {
      avatarPath = '';
    } else if (avatar.startsWith('data:image/')) {
      avatarPath = await _upload(avatar, '${user.id}/avatar');
    }
    await _db
        .from('profiles')
        .update({
          'name': (data['name'] as String).trim(),
          'bio': (data['bio'] as String? ?? '').trim(),
          'avatar_path': avatarPath,
        })
        .eq('id', user.id);
    if (previousPath.isNotEmpty && previousPath != avatarPath) {
      await _db.storage.from(_bucket).remove([
        _normalizeStoragePath(previousPath),
      ]);
    }
    return _getProfile();
  }

  Future<Map<String, dynamic>> _getPosts(
    String path, {
    required bool own,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    final uri = Uri.parse(path);
    final before = int.tryParse(uri.queryParameters['before'] ?? '') ?? 0;
    var query = _db.from('posts').select();
    if (own) query = query.eq('user_id', user.id);
    if (before > 0) query = query.lt('id', before);
    final rows = await query.order('id', ascending: false).limit(13);
    final page = rows.take(12).toList();
    if (page.isEmpty) return {'posts': <Map<String, dynamic>>[], 'next': null};
    final ids = page.map((row) => row['id'] as int).toList();
    final authors = page
        .map((row) => row['user_id'] as String)
        .toSet()
        .toList();
    final profiles = await _db
        .from('profiles')
        .select('id,name,avatar_path')
        .inFilter('id', authors);
    final profileById = {
      for (final item in profiles) item['id'] as String: item,
    };
    final likes = await _db
        .from('likes')
        .select('post_id,user_id')
        .inFilter('post_id', ids);
    final likeRows = likes.cast<Map<String, dynamic>>();
    final currentUserId = user.id;
    final cards = await Future.wait(
      page.map((row) async {
        final profile = profileById[row['user_id']] ?? <String, dynamic>{};
        final photoLikes = likeRows
            .where((like) => like['post_id'] == row['id'])
            .toList();
        final avatarPath = _normalizeStoragePath(
          profile['avatar_path'] as String? ?? '',
        );
        return <String, dynamic>{
          'id': row['id'],
          'user_id': row['user_id'],
          'name': profile['name'] ?? 'Cloud watcher',
          'avatar': avatarPath.isEmpty ? '' : await _signedImage(avatarPath),
          'image': await _signedImage(row['image_path'] as String),
          'caption': row['caption'],
          'location': row['location'] ?? '',
          'best': row['best'] == true ? 1 : 0,
          'liked': photoLikes.any((like) => like['user_id'] == currentUserId)
              ? 1
              : 0,
          'like_count': photoLikes.length,
          'created_at':
              DateTime.parse(row['created_at'] as String)
                  .millisecondsSinceEpoch ~/
              1000,
        };
      }),
    );
    return {'posts': cards, 'next': rows.length > 12 ? page.last['id'] : null};
  }

  Future<Map<String, dynamic>> _createPost(Map<String, dynamic> data) async {
    final user = _db.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    final imagePath = await _upload(data['image'] as String, '${user.id}/post');
    try {
      final row = await _db
          .from('posts')
          .insert({
            'user_id': user.id,
            'image_path': imagePath,
            'caption': (data['caption'] as String).trim(),
            'location': (data['location'] as String? ?? '').trim(),
            'best': data['best'] == true,
          })
          .select('id')
          .single();
      return {'id': row['id']};
    } catch (_) {
      await _db.storage.from(_bucket).remove([
        _normalizeStoragePath(imagePath),
      ]);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _postAction(
    int id,
    String action,
    Map<String, dynamic> data,
  ) async {
    final user = _db.auth.currentUser;
    if (user == null) throw const AuthException('Please log in again.');
    if (action == 'like') {
      final liked = data['liked'] == true;
      if (liked) {
        await _db.from('likes').upsert({
          'user_id': user.id,
          'post_id': id,
        }, onConflict: 'user_id,post_id');
      } else {
        await _db
            .from('likes')
            .delete()
            .eq('user_id', user.id)
            .eq('post_id', id);
      }
      final rows = await _db.from('likes').select('user_id').eq('post_id', id);
      return {'liked': liked, 'likes': rows.length};
    }
    if (action == 'best') {
      await _db
          .from('posts')
          .update({'best': data['best'] == true})
          .eq('id', id)
          .eq('user_id', user.id);
      return {'status': 'ok'};
    }
    if (action == 'delete') {
      final row = await _db
          .from('posts')
          .select('image_path')
          .eq('id', id)
          .eq('user_id', user.id)
          .single();
      await _db.from('posts').delete().eq('id', id).eq('user_id', user.id);
      await _db.storage.from(_bucket).remove([
        _normalizeStoragePath(row['image_path'] as String),
      ]);
      return {'status': 'ok'};
    }
    throw const AuthException('That Cloud Club action is not available.');
  }

  Future<String> _upload(String dataUrl, String prefix) async {
    final header = dataUrl.split(',').first;
    final mime = header.substring('data:'.length, header.indexOf(';'));
    final extension = switch (mime) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => throw const AuthException('Choose a JPEG, PNG or WebP photo.'),
    };
    final bytes = Uint8List.fromList(base64Decode(dataUrl.split(',').last));
    if (bytes.length > 5000000) {
      throw const AuthException('Choose a photo under 5 MB.');
    }
    final path = '$prefix-${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _db.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: sb.FileOptions(contentType: mime, cacheControl: '3600'),
        );
    // Storage APIs that take a path expect it relative to the bucket. Keep
    // that canonical form in the database and use it for signed URLs/removal.
    return path;
  }

  String _normalizeStoragePath(String path) {
    final clean = path.replaceFirst(RegExp(r'^/+'), '');
    final bucketPrefix = '$_bucket/';
    return clean.startsWith(bucketPrefix)
        ? clean.substring(bucketPrefix.length)
        : clean;
  }

  Future<String> _signedImage(String path) => _db.storage
      .from(_bucket)
      .createSignedUrl(_normalizeStoragePath(path), 3600);

  @override
  void close() {}
}
