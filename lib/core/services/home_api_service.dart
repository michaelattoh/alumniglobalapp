import 'dart:convert';
import 'dart:io';

import 'package:alumni_global_app/core/config/api_config.dart';
import 'package:alumni_global_app/core/services/auth_session.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class HomeApiService {
  HomeApiService._();

  static const Duration _timeout = Duration(seconds: 12);

  static Map<String, dynamic> _cachedFeed = {};
  static List<Map<String, dynamic>> _cachedStories = [];
  static List<Map<String, dynamic>> _cachedEvents = [];
  static Map<String, List<Map<String, dynamic>>> _cachedRecommendations = {};
  static List<Map<String, dynamic>> _cachedFundings = [];
  static List<Map<String, dynamic>> _cachedNotifications = [];
  static final Map<int, Map<String, dynamic>> _cachedPosts = {};
  static List<Map<String, dynamic>> _pendingPosts = [];
  static List<Map<String, dynamic>> _pendingStories = [];
  static List<Map<String, dynamic>> _cachedMentionableUsers = [];
  static Map<String, dynamic>? _cachedMe;

  static Map<String, dynamic> getCachedFeed() => _cachedFeed;
  static Map<String, dynamic>? getCachedMe() => _cachedMe;
  static List<Map<String, dynamic>> getCachedStories() => _cachedStories;
  static List<Map<String, dynamic>> getCachedEvents() => _cachedEvents;
  static List<Map<String, dynamic>> getCachedRecommendations(String type) =>
      _cachedRecommendations[type] ?? const [];
  static List<Map<String, dynamic>> getCachedFundings() => _cachedFundings;
  static List<Map<String, dynamic>> getCachedNotifications() =>
      _cachedNotifications;
  static Map<String, dynamic>? getCachedPost(int postId) =>
      _cachedPosts[postId];
  static void cachePost(Map<String, dynamic> post) {
    final postId = (post['id'] as num?)?.toInt();
    if (postId != null) {
      _cachedPosts[postId] = post;
    }
  }

  static void cacheMe(Map<String, dynamic>? user) {
    _cachedMe = user == null ? null : Map<String, dynamic>.from(user);
  }

  static bool get isInstitutionAccessRestricted {
    final user = _cachedMe;
    final institution = user?['institution'];
    if (institution is! Map) return false;
    final status = institution['status']?.toString().toLowerCase();
    return status == 'on_hold' || status == 'suspended';
  }

  static String get accessRestrictionMessage =>
      'Access temporarily restricted. Your organization account is currently on hold. Please contact support for assistance.';

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static void updateCachedPostState(
    int postId, {
    bool? isSaved,
    bool? isLiked,
    String? reactionType,
    int? reactionCount,
    int? commentCount,
  }) {
    Map<String, dynamic> mutate(Map<String, dynamic> post) {
      final next = Map<String, dynamic>.from(post);
      if (isSaved != null) next['is_saved'] = isSaved;
      if (isLiked != null) next['is_liked'] = isLiked;
      if (reactionType != null || isLiked == false) {
        next['user_reaction'] = isLiked == false ? null : reactionType;
      }
      final counts = Map<String, dynamic>.from(
        (next['counts'] as Map?) ?? const {},
      );
      if (reactionCount != null) counts['reactions'] = reactionCount;
      if (commentCount != null) counts['comments'] = commentCount;
      next['counts'] = counts;
      return next;
    }

    final cached = _cachedPosts[postId];
    if (cached != null) {
      _cachedPosts[postId] = mutate(cached);
    }

    void rewriteList(List<Map<String, dynamic>> rows) {
      final index = rows.indexWhere((row) => _asInt(row['id']) == postId);
      if (index >= 0) {
        rows[index] = mutate(rows[index]);
      }
    }

    rewriteList(_pendingPosts);
    if (_cachedFeed.isNotEmpty) {
      final posts = ((_cachedFeed['posts'] as List?) ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      rewriteList(posts);
      _cachedFeed = {..._cachedFeed, 'posts': posts};
    }
  }

  static List<Map<String, dynamic>> getPendingPosts() => _pendingPosts;
  static void setPendingPosts(List<Map<String, dynamic>> posts) {
    _pendingPosts = posts;
  }

  static void addPendingPost(Map<String, dynamic> post) {
    final postId = _asInt(post['id']);
    if (postId == null) return;
    _cachedPosts[postId] = post;
    _pendingPosts = [
      post,
      ..._pendingPosts.where((p) => _asInt(p['id']) != postId),
    ];
  }

  static List<Map<String, dynamic>> getPendingStories() => _pendingStories;
  static void setPendingStories(List<Map<String, dynamic>> stories) {
    _pendingStories = stories;
  }

  static void addPendingStory(Map<String, dynamic> story) {
    final storyId = _asInt(story['id']);
    if (storyId == null) return;
    _cachedStories = [
      _normalizeStory(story),
      ..._cachedStories.where((s) => _asInt(s['id']) != storyId),
    ];
    _pendingStories = [
      story,
      ..._pendingStories.where((s) => _asInt(s['id']) != storyId),
    ];
  }

  static void removePendingStory(int storyId) {
    _pendingStories = _pendingStories
        .where((story) => _asInt(story['id']) != storyId)
        .toList();
    _cachedStories = _cachedStories
        .where((story) => _asInt(story['id']) != storyId)
        .toList();
  }

  static String? normalizeMediaUrl(String? url) =>
      _normalizeMediaUrl(url) ?? url;

  static List<Map<String, dynamic>> _normalizeMediaItems(List? media) {
    if (media == null) return const [];
    return media.map((entry) {
      final item = Map<String, dynamic>.from((entry as Map?) ?? const {});
      final rawUrl = item['url']?.toString();
      final rawThumb = item['thumbnail_url']?.toString();
      if (rawUrl != null && rawUrl.isNotEmpty) {
        item['url'] = _normalizeMediaUrl(rawUrl) ?? rawUrl;
      }
      if (rawThumb != null && rawThumb.isNotEmpty) {
        item['thumbnail_url'] = _normalizeMediaUrl(rawThumb) ?? rawThumb;
      }
      return item;
    }).toList();
  }

  static Map<String, dynamic> _normalizePost(Map<String, dynamic> post) {
    final normalized = Map<String, dynamic>.from(post);
    final user = Map<String, dynamic>.from(
      (normalized['user'] as Map?) ?? const {},
    );
    final avatarUrl = user['avatar_url']?.toString();
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      user['avatar_url'] = _normalizeMediaUrl(avatarUrl) ?? avatarUrl;
    }
    normalized['user'] = user;
    normalized['media'] = _normalizeMediaItems(normalized['media'] as List?);
    return normalized;
  }

  static Map<String, dynamic> _normalizeStory(Map<String, dynamic> story) {
    final normalized = Map<String, dynamic>.from(story);
    final user = Map<String, dynamic>.from(
      (normalized['user'] as Map?) ?? const {},
    );
    final avatarUrl = user['avatar_url']?.toString();
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      user['avatar_url'] = _normalizeMediaUrl(avatarUrl) ?? avatarUrl;
    }
    normalized['user'] = user;
    normalized['media'] = _normalizeMediaItems(normalized['media'] as List?);
    return normalized;
  }

  static String? _normalizeMediaUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final base = Uri.parse(ApiConfig.baseUrl);
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final uri = Uri.tryParse(url);
      if (uri == null) return url;
      final host = uri.host;
      if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
        return uri
            .replace(
              scheme: base.scheme,
              host: base.host,
              port: base.hasPort ? base.port : null,
            )
            .toString();
      }
      return url;
    }
    if (url.startsWith('/')) return '${ApiConfig.baseUrl}$url';
    return '${ApiConfig.baseUrl}/$url';
  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthSession.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<Map<String, dynamic>>> fetchFeedPosts() async {
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/api/feed/global?sort=chrono'),
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final posts = (body['posts']?['data'] as List?) ?? const [];
    return posts.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> fetchFeed({
    String sort = 'chrono',
    int page = 1,
    int perPage = 15,
  }) async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/posts?page=$page&per_page=$perPage',
          ),
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      if (_cachedFeed.isNotEmpty) {
        return _cachedFeed;
      }
      return {
        'posts': <Map<String, dynamic>>[],
        'announcements': <Map<String, dynamic>>[],
        'posts_meta': null,
      };
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final posts = (body['data'] as List?) ?? const [];
    final payload = {
      'posts': posts.cast<Map<String, dynamic>>().map(_normalizePost).toList(),
      'announcements': <Map<String, dynamic>>[],
      'posts_meta': body['meta'],
    };
    if (page == 1) {
      _cachedFeed = payload;
    }
    return payload;
  }

  static Future<bool> resendVerificationEmail(String email) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/resend-verification'),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'email': email}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> forgotPassword(String email) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/forgot-password'),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'email': email}),
        )
        .timeout(_timeout);

    return response.statusCode == 200;
  }

  static Future<List<Map<String, dynamic>>> fetchStories({
    int perPage = 20,
  }) async {
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/api/stories?per_page=$perPage'),
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) return _cachedStories;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    _cachedStories = data
        .cast<Map<String, dynamic>>()
        .map(_normalizeStory)
        .toList();
    return _cachedStories;
  }

  static Future<List<Map<String, dynamic>>> fetchEvents({
    int perPage = 20,
  }) async {
    final data = await fetchEventsPage(page: 1, perPage: perPage);
    return (data['data'] as List<Map<String, dynamic>>?) ?? [];
  }

  static Future<Map<String, dynamic>> fetchRecommendations({
    String type = 'content',
    int page = 1,
    int perPage = 10,
  }) async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/recommendations?type=$type&page=$page&per_page=$perPage',
          ),
          headers: await _headers(),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      return {
        'data': _cachedRecommendations[type] ?? <Map<String, dynamic>>[],
        'meta': null,
      };
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    final payload = {
      'data': data.cast<Map<String, dynamic>>(),
      'meta': body['meta'],
    };
    if (page == 1) {
      _cachedRecommendations[type] =
          payload['data'] as List<Map<String, dynamic>>;
    }
    return payload;
  }

  static Future<bool> sendRecommendationFeedback({
    required int recommendationId,
    required String action,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/recommendations/$recommendationId/feedback',
      ),
      headers: await _headers(),
      body: jsonEncode({'action': action}),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> fetchEventsPage({
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/events?page=$page&per_page=$perPage',
          ),
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (response.statusCode != 200)
      return {'data': _cachedEvents, 'meta': null};
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    final payload = {
      'data': data.cast<Map<String, dynamic>>(),
      'meta': body['meta'],
    };
    if (page == 1) {
      _cachedEvents = payload['data'] as List<Map<String, dynamic>>;
    }
    return payload;
  }

  static Future<Map<String, dynamic>?> fetchEvent(int eventId) async {
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/api/events/$eventId'),
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['event'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> createEvent({
    required String title,
    required String eventType,
    required DateTime startsAt,
    DateTime? endsAt,
    String? description,
    String? location,
    String? meetingUrl,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/events'),
      headers: await _headers(),
      body: jsonEncode({
        'title': title,
        'event_type': eventType,
        'starts_at': startsAt.toUtc().toIso8601String(),
        if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
        'description': description,
        'location': location,
        'meeting_url': meetingUrl,
      }),
    );
    if (response.statusCode != 201) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['event'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> fetchInstitutionPublic(
    int institutionId,
  ) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/institutions/public/$institutionId'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['institution'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> fetchMyInstitution() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/institutions/me'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final institution = body['institution'];
    return institution is Map ? Map<String, dynamic>.from(institution) : null;
  }

  static Future<Map<String, dynamic>?> updateMyInstitution(
    Map<String, dynamic> payload,
  ) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/institutions/me'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final institution = body['institution'];
    return institution is Map ? Map<String, dynamic>.from(institution) : null;
  }

  static Future<List<Map<String, dynamic>>> searchInstitutions(
    String query,
  ) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/institutions/public?search=$query'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>?> fetchUserProfile(int userId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/profiles/$userId'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['user'] as Map<String, dynamic>?;
  }

  static Future<List<Map<String, dynamic>>> fetchVerificationRequests({
    String status = 'pending',
    int? institutionId,
    int page = 1,
    int perPage = 10,
  }) async {
    final params = <String, String>{
      'status': status,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (institutionId != null) {
      params['institution_id'] = institutionId.toString();
    }
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/admin/verification-requests',
    ).replace(queryParameters: params);
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  static Future<bool> verifyProfile(int userId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/profiles/$userId/verify'),
      headers: await _headers(),
      body: jsonEncode({}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> rejectProfile(int userId, {String? reason}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/profiles/$userId/reject'),
      headers: await _headers(),
      body: jsonEncode({
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>?> rsvpEvent({
    required int eventId,
    required String status,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/events/$eventId/rsvp'),
      headers: await _headers(),
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final event = body['event'];
    if (event is Map) {
      final next = Map<String, dynamic>.from(event);
      final index = _cachedEvents.indexWhere(
        (row) => _asInt(row['id']) == eventId,
      );
      if (index >= 0) {
        _cachedEvents[index] = next;
      }
      return next;
    }
    return const <String, dynamic>{};
  }

  static Future<Map<String, dynamic>?> createJob({
    required String title,
    String? category,
    String? companyName,
    String? location,
    String? workMode,
    String? salary,
    String? experienceLevel,
    String? overview,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/admin/jobs'),
      headers: await _headers(),
      body: jsonEncode({
        'title': title,
        if (category != null && category.isNotEmpty) 'category': category,
        if (companyName != null && companyName.isNotEmpty)
          'company_name': companyName,
        if (location != null && location.isNotEmpty) 'location': location,
        if (workMode != null && workMode.isNotEmpty) 'work_mode': workMode,
        if (salary != null && salary.isNotEmpty) 'salary': salary,
        if (experienceLevel != null && experienceLevel.isNotEmpty)
          'experience_level': experienceLevel,
        if (overview != null && overview.isNotEmpty) 'overview': overview,
        if (description != null && description.isNotEmpty)
          'description': description,
      }),
    );
    if (response.statusCode != 201) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['job'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> createAnnouncement({
    required String title,
    required String body,
    bool sendEmail = false,
    bool isActive = true,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/announcements'),
      headers: await _headers(),
      body: jsonEncode({
        'title': title,
        'body': body,
        'audience': 'institution',
        'send_email': sendEmail,
        'is_active': isActive,
      }),
    );
    if (response.statusCode != 201) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['announcement'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> createPost({
    required String content,
    List<Map<String, dynamic>> media = const [],
    String? scheduledAt,
    String visibility = 'public',
    int? institutionId,
    List<int> mentions = const [],
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/posts'),
      headers: await _headers(),
      body: jsonEncode({
        'content': content,
        'visibility': visibility,
        if (institutionId != null) 'institution_id': institutionId,
        if (scheduledAt != null) 'scheduled_at': scheduledAt,
        if (mentions.isNotEmpty) 'mentions': mentions,
        if (media.isNotEmpty) 'media': media,
      }),
    );
    if (response.statusCode != 201) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final post = body['post'] as Map<String, dynamic>?;
    return post == null ? null : _normalizePost(post);
  }

  static Future<Map<String, dynamic>?> fetchAd({
    required String placement,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/ads/serve'),
      headers: await _headers(),
      body: jsonEncode({'placement': placement}),
    );

    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>?;
  }

  static Future<void> clickAd(int adId) async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/ads/$adId/click'),
      headers: await _headers(),
    );
  }

  static Future<List<int>> fetchHiddenAds() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/ads/hidden'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return data.map((e) => (e as num).toInt()).toList();
  }

  static Future<void> hideAd(int adId) async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/ads/$adId/hide'),
      headers: await _headers(),
    );
  }

  static Future<Map<String, dynamic>?> createAd({
    required String title,
    required String placement,
    required String objective,
    required String pricingModel,
    required double price,
    required double budget,
    required String currency,
    String? content,
    String? mediaUrl,
    String? targetUrl,
    String? targetLocation,
    List<String> targetInterests = const [],
    bool dailyCapEnabled = false,
    double? dailyBudget,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/ads'),
      headers: await _headers(),
      body: jsonEncode({
        'title': title,
        'placement': placement,
        'objective': objective,
        'pricing_model': pricingModel,
        'price': price,
        'budget': budget,
        'currency': currency,
        'content': content,
        'media_url': mediaUrl,
        'target_url': targetUrl,
        'target_location': targetLocation,
        'target_interests': targetInterests,
        'daily_cap_enabled': dailyCapEnabled,
        'daily_budget': dailyBudget,
      }),
    );

    if (response.statusCode != 201 && response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['ad'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>> fetchScheduledPosts({
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/posts/scheduled?page=$page&per_page=$perPage',
      ),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      return {'data': <Map<String, dynamic>>[], 'meta': null};
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return {
      'data': data.cast<Map<String, dynamic>>().map(_normalizePost).toList(),
      'meta': body['meta'],
    };
  }

  static Future<bool> publishScheduledPost(int postId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId/publish-now'),
      headers: await _headers(),
      body: jsonEncode({}),
    );
    return response.statusCode == 200;
  }

  static Future<List<Map<String, dynamic>>> fetchPostComments(
    int postId, {
    int perPage = 30,
  }) async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/posts/$postId/comments?per_page=$perPage',
          ),
          headers: await _headers(),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return data.cast<Map<String, dynamic>>().map((item) {
      final next = Map<String, dynamic>.from(item);
      next['user'] = Map<String, dynamic>.from(
        (next['user'] as Map?) ?? const {},
      );
      return next;
    }).toList();
  }

  static Future<Map<String, dynamic>?> likePostComment(int commentId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/comments/$commentId/like'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final comment = body['comment'] as Map<String, dynamic>?;
    return comment == null ? null : Map<String, dynamic>.from(comment);
  }

  static Future<Map<String, dynamic>?> unlikePostComment(int commentId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/comments/$commentId/like'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final comment = body['comment'] as Map<String, dynamic>?;
    return comment == null ? null : Map<String, dynamic>.from(comment);
  }

  static Future<bool> addPostComment(
    int postId,
    String content, {
    int? parentId,
    List<int> mentions = const [],
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId/comments'),
      headers: await _headers(),
      body: jsonEncode({
        'content': content,
        if (parentId != null) 'parent_id': parentId,
        if (mentions.isNotEmpty) 'mentions': mentions,
      }),
    );
    return response.statusCode == 201;
  }

  static Future<List<Map<String, dynamic>>> fetchMentionableUsers({
    bool refresh = false,
  }) async {
    if (!refresh && _cachedMentionableUsers.isNotEmpty) {
      return _cachedMentionableUsers;
    }

    final connections = await fetchConnections(perPage: 100);
    final sent =
        (connections['sent'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];
    final received =
        (connections['received'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];

    Map<String, dynamic> mapUser(Map<String, dynamic> row, String key) {
      final user = Map<String, dynamic>.from(
        (row[key] as Map?) ?? const <String, dynamic>{},
      );
      return {
        'id': _asInt(user['id']),
        'name': (user['name'] ?? '').toString(),
        'avatar_url': normalizeMediaUrl(user['avatar_url']?.toString()),
      };
    }

    final users =
        <Map<String, dynamic>>[
              ...sent
                  .where((row) => row['status']?.toString() == 'accepted')
                  .map((row) => mapUser(row, 'to_user')),
              ...received
                  .where((row) => row['status']?.toString() == 'accepted')
                  .map((row) => mapUser(row, 'from_user')),
            ]
            .where(
              (row) => row['id'] != null && (row['name'] as String).isNotEmpty,
            )
            .fold<List<Map<String, dynamic>>>([], (acc, row) {
              if (acc.every((existing) => existing['id'] != row['id'])) {
                acc.add(row);
              }
              return acc;
            });

    _cachedMentionableUsers = users;
    return users;
  }

  static Future<Map<String, dynamic>?> fetchPost(int postId) async {
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId'),
          headers: await _headers(),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) return _cachedPosts[postId];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rawPost = body['post'] as Map<String, dynamic>?;
    final post = rawPost == null ? null : _normalizePost(rawPost);
    if (post != null) {
      _cachedPosts[postId] = post;
    }
    return post;
  }

  static Future<bool> deletePost(int postId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId'),
      headers: await _headers(),
    );
    return response.statusCode == 200;
  }

  static Future<bool> likePost(int postId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId/like'),
      headers: await _headers(),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>?> reactToPost(
    int postId, {
    required String type,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId/like'),
      headers: await _headers(),
      body: jsonEncode({'type': type}),
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final post = body['post'] as Map<String, dynamic>?;
    if (post == null) return null;
    final normalized = _normalizePost(post);
    cachePost(normalized);
    updateCachedPostState(
      postId,
      isLiked: normalized['is_liked'] == true,
      reactionType: normalized['user_reaction']?.toString(),
      reactionCount: _asInt((normalized['counts'] as Map?)?['reactions']),
    );
    return normalized;
  }

  static Future<Map<String, dynamic>?> unlikePost(int postId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId/like'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final post = body['post'] as Map<String, dynamic>?;
    if (post == null) return null;
    final normalized = _normalizePost(post);
    cachePost(normalized);
    updateCachedPostState(
      postId,
      isLiked: normalized['is_liked'] == true,
      reactionType: normalized['user_reaction']?.toString(),
      reactionCount: _asInt((normalized['counts'] as Map?)?['reactions']),
    );
    return normalized;
  }

  static Future<bool> repostPost(int postId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId/repost'),
      headers: await _headers(),
    );
    return response.statusCode == 200;
  }

  static Future<bool> unrepostPost(int postId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId/repost'),
      headers: await _headers(),
    );
    return response.statusCode == 200;
  }

  static Future<bool> sharePost(int postId, {String? channel}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId/share'),
      headers: await _headers(),
      body: jsonEncode({
        if (channel != null && channel.isNotEmpty) 'channel': channel,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<bool> reportPost(int postId, {String? reason}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId/report'),
      headers: await _headers(),
      body: jsonEncode({
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      }),
    );
    return response.statusCode == 200;
  }

  static Future<bool> savePost(int postId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId/save'),
      headers: await _headers(),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> unsavePost(int postId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId/save'),
      headers: await _headers(),
    );
    return response.statusCode == 200;
  }

  static Future<bool> hidePost(int postId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId/hide'),
      headers: await _headers(),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> unhidePost(int postId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/posts/$postId/hide'),
      headers: await _headers(),
    );
    return response.statusCode == 200;
  }

  static Future<bool> muteUser(int userId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/mute'),
      headers: await _headers(),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> unmuteUser(int userId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/mute'),
      headers: await _headers(),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> fetchSavedPosts({
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/posts/saved?page=$page&per_page=$perPage',
      ),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      return {'data': <Map<String, dynamic>>[], 'meta': null};
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return {
      'data': data.cast<Map<String, dynamic>>().map(_normalizePost).toList(),
      'meta': body['meta'],
    };
  }

  static Future<Map<String, dynamic>> fetchHiddenPosts({
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/posts/hidden?page=$page&per_page=$perPage',
      ),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      return {'data': <Map<String, dynamic>>[], 'meta': null};
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return {'data': data.cast<Map<String, dynamic>>(), 'meta': body['meta']};
  }

  static Future<List<Map<String, dynamic>>> fetchMutedUsers() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/users/muted'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> fetchNotificationsPage({
    int page = 1,
    int perPage = 30,
  }) async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/notifications?page=$page&per_page=$perPage',
          ),
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      return {'data': _cachedNotifications, 'meta': null};
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (body['data'] as List?) ?? const [];
    final payload = {
      'data': list.cast<Map<String, dynamic>>(),
      'meta': body['meta'],
    };
    if (page == 1) {
      _cachedNotifications = payload['data'] as List<Map<String, dynamic>>;
    }
    return payload;
  }

  static Future<void> markNotificationRead(int id) async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/notifications/$id/read'),
      headers: await _headers(),
    );
    _cachedNotifications = _cachedNotifications.map((row) {
      if ((row['id'] as num?)?.toInt() != id) return row;
      return {
        ...row,
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  static Future<void> markAllNotificationsRead() async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/notifications/read-all'),
      headers: await _headers(),
    );
    _cachedNotifications = _cachedNotifications.map((row) {
      return {
        ...row,
        'is_read': true,
        'read_at': DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  static Future<int?> fetchUnreadNotificationsCount() async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/notifications?page=1&per_page=100',
          ),
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (body['data'] as List?) ?? const [];
    var unread = 0;
    for (final row in list) {
      if (row is Map && row['is_read'] != true) unread += 1;
    }
    return unread;
  }

  static Future<int?> fetchUnreadSupportNotificationsCount() async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/notifications?page=1&per_page=100',
          ),
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (body['data'] as List?) ?? const [];
    var unread = 0;
    for (final row in list) {
      if (row is! Map || row['is_read'] == true) continue;
      final type = (row['type'] ?? '').toString();
      if (type.contains('support')) unread += 1;
    }
    return unread;
  }

  static Future<List<Map<String, dynamic>>> fetchDonationCampaigns() async {
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/api/donation-campaigns?per_page=50'),
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) return _cachedFundings;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (body['data'] as List?) ?? const [];
    _cachedFundings = list.cast<Map<String, dynamic>>();
    return _cachedFundings;
  }

  static Future<Map<String, dynamic>?> createDonationCampaign({
    required String title,
    required double targetAmount,
    required String currency,
    String? description,
    String? imageUrl,
    bool isActive = true,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/donation-campaigns'),
      headers: await _headers(),
      body: jsonEncode({
        'title': title,
        'target_amount': targetAmount,
        'currency': currency,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        'is_active': isActive,
      }),
    );
    if (response.statusCode != 201) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['campaign'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> updateDonationCampaign({
    required int campaignId,
    String? title,
    double? targetAmount,
    String? currency,
    String? description,
    String? imageUrl,
    bool? isActive,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/donation-campaigns/$campaignId'),
      headers: await _headers(),
      body: jsonEncode({
        if (title != null) 'title': title,
        if (targetAmount != null) 'target_amount': targetAmount,
        if (currency != null) 'currency': currency,
        if (description != null) 'description': description,
        if (imageUrl != null) 'image_url': imageUrl,
        if (isActive != null) 'is_active': isActive,
      }),
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['campaign'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>> donateToCampaign({
    required int campaignId,
    required double amount,
    required String provider,
    required String currency,
    String? message,
    bool isAnonymous = false,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/donation-campaigns/$campaignId/donate',
      ),
      headers: await _headers(),
      body: jsonEncode({
        'provider': provider,
        'amount': amount,
        'currency': currency,
        'is_anonymous': isAnonymous,
        if (message != null && message.isNotEmpty) 'message': message,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'ok': true,
          'checkout_url': body['checkout_url']?.toString(),
          'message': body['message']?.toString(),
        };
      } catch (_) {
        return {'ok': true};
      }
    }

    String errorMessage = 'Payment failed. Please try again.';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['message'] != null) {
        errorMessage = body['message'].toString();
      }
    } catch (_) {}

    return {'ok': false, 'message': errorMessage};
  }

  static Future<Map<String, dynamic>> fetchConnections({
    int perPage = 30,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/connections?per_page=$perPage'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      return {
        'sent': <Map<String, dynamic>>[],
        'received': <Map<String, dynamic>>[],
      };
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final sent = (body['sent']?['data'] as List?) ?? const [];
    final received = (body['received']?['data'] as List?) ?? const [];

    return {
      'sent': sent.cast<Map<String, dynamic>>(),
      'received': received.cast<Map<String, dynamic>>(),
    };
  }

  static Future<bool> respondConnection({
    required int connectionId,
    required String status,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/connections/$connectionId/respond'),
      headers: await _headers(),
      body: jsonEncode({'status': status}),
    );

    return response.statusCode == 200;
  }

  static Future<bool> sendConnection(
    int userId, {
    String? message,
    String? source,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/connections/$userId'),
      headers: await _headers(),
      body: jsonEncode({
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
        if (source != null && source.trim().isNotEmpty) 'source': source.trim(),
      }),
    );

    return response.statusCode == 201;
  }

  static Future<List<Map<String, dynamic>>> fetchInstitutionYearGroups(
    int institutionId,
  ) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/institutions/$institutionId/year-groups',
      ),
      headers: await _headers(),
    );

    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> fetchInstitutionYearGroupRequests({
    required int institutionId,
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/institutions/$institutionId/year-group-requests?page=$page&per_page=$perPage',
      ),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      return {'data': <Map<String, dynamic>>[], 'meta': null};
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return {'data': data.cast<Map<String, dynamic>>(), 'meta': body['meta']};
  }

  static Future<Map<String, dynamic>> createInstitutionYearGroup({
    required int institutionId,
    required String name,
    int? graduationYear,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/institutions/$institutionId/year-groups',
      ),
      headers: await _headers(),
      body: jsonEncode({
        'name': name.trim(),
        if (graduationYear != null) 'graduation_year': graduationYear,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      }),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      return {'ok': false};
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return {'ok': true, 'group': body['group']};
  }

  static Future<Map<String, dynamic>> requestInstitutionYearGroupJoin({
    required int institutionId,
    required int groupId,
    String? intro,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/institutions/$institutionId/year-groups/$groupId/join',
      ),
      headers: await _headers(),
      body: jsonEncode({
        if (intro != null && intro.trim().isNotEmpty) 'intro': intro.trim(),
      }),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      String? message;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['message']?.toString();
      } catch (_) {}
      return {'ok': false, 'message': message};
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return {
      'ok': true,
      'membership': body['membership'],
      'message': body['message']?.toString(),
    };
  }

  static Future<bool> respondInstitutionYearGroupRequest({
    required int institutionId,
    required int membershipId,
    required String status,
  }) async {
    final action = status == 'accepted' ? 'approve' : 'reject';
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/institutions/$institutionId/year-group-requests/$membershipId/$action',
      ),
      headers: await _headers(),
      body: jsonEncode({}),
    );

    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> addInstitutionYearGroupMember({
    required int institutionId,
    required int groupId,
    required int userId,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/institutions/$institutionId/year-groups/$groupId/members',
      ),
      headers: await _headers(),
      body: jsonEncode({'user_id': userId}),
    );

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }
    return {
      'ok': response.statusCode == 200 || response.statusCode == 201,
      'message': body?['message']?.toString(),
      'membership': body?['membership'],
    };
  }

  static Future<List<Map<String, dynamic>>> fetchDirectorySuggestions() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/directory?per_page=20'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    final meId = _asInt(_cachedMe?['id']);
    return data
        .cast<Map<String, dynamic>>()
        .where((row) => _asInt(row['id']) != null && _asInt(row['id']) != meId)
        .toList();
  }

  static Future<List<Map<String, dynamic>>> searchDirectoryUsers(
    String query, {
    int perPage = 20,
  }) async {
    final data = await searchDirectoryUsersPage(
      query,
      page: 1,
      perPage: perPage,
    );
    return (data['data'] as List<Map<String, dynamic>>?) ?? [];
  }

  static Future<Map<String, dynamic>> searchDirectoryUsersPage(
    String query, {
    int page = 1,
    int perPage = 20,
    int? graduationYear,
    String? industry,
    int? institutionId,
  }) async {
    final q = query.trim();
    final trimmedIndustry = industry?.trim() ?? '';
    final currentYear = DateTime.now().year;
    final safeGraduationYear =
        graduationYear != null &&
            graduationYear >= 1950 &&
            graduationYear <= currentYear
        ? graduationYear
        : null;
    if (q.isEmpty &&
        graduationYear == null &&
        trimmedIndustry.isEmpty &&
        institutionId == null) {
      return {'data': <Map<String, dynamic>>[], 'meta': null};
    }

    final params = <String, String>{'page': '$page', 'per_page': '$perPage'};
    if (q.isNotEmpty) {
      params['q'] = q;
    }
    if (safeGraduationYear != null) {
      params['graduation_year'] = '$safeGraduationYear';
    }
    if (trimmedIndustry.isNotEmpty) {
      params['industry'] = trimmedIndustry;
    }
    if (institutionId != null) {
      params['institution_id'] = '$institutionId';
    }

    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/directory',
      ).replace(queryParameters: params),
      headers: await _headers(),
    );

    if (response.statusCode != 200)
      return {'data': <Map<String, dynamic>>[], 'meta': null};
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return {'data': data.cast<Map<String, dynamic>>(), 'meta': body['meta']};
  }

  static Future<Map<String, dynamic>> fetchPaymentHistory({
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/payments/history?page=$page&per_page=$perPage',
      ),
      headers: await _headers(),
    );

    if (response.statusCode != 200)
      return {'data': <Map<String, dynamic>>[], 'meta': null};
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return {'data': data.cast<Map<String, dynamic>>(), 'meta': body['meta']};
  }

  static Future<Map<String, dynamic>> fetchSupportTickets({
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/support/tickets?page=$page&per_page=$perPage',
      ),
      headers: await _headers(),
    );

    if (response.statusCode != 200)
      return {'data': <Map<String, dynamic>>[], 'meta': null};
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return {'data': data.cast<Map<String, dynamic>>(), 'meta': body['meta']};
  }

  static Future<bool> createSupportTicket({
    required String subject,
    required String message,
    String? category,
    String? priority,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/support/tickets'),
      headers: await _headers(),
      body: jsonEncode({
        'subject': subject,
        'message': message,
        if (category != null) 'category': category,
        if (priority != null) 'priority': priority,
      }),
    );

    return response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> replySupportTicket({
    required int ticketId,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/support/tickets/$ticketId/reply'),
      headers: await _headers(),
      body: jsonEncode({'message': message}),
    );

    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    return {
      'ok': response.statusCode >= 200 && response.statusCode < 300,
      'message': body['message']?.toString() ?? 'Failed to send reply',
      'ticket': body['ticket'] is Map<String, dynamic>
          ? body['ticket'] as Map<String, dynamic>
          : body['ticket'] is Map
          ? Map<String, dynamic>.from(body['ticket'] as Map)
          : null,
      'statusCode': response.statusCode,
    };
  }

  static Future<Map<String, dynamic>> fetchNotificationPreferences() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/notification-preferences'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) return {};
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as Map<String, dynamic>?) ?? {};
  }

  static Future<bool> updateNotificationPreferences(
    Map<String, dynamic> prefs,
  ) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/notification-preferences'),
      headers: await _headers(),
      body: jsonEncode(prefs),
    );

    return response.statusCode == 200;
  }

  static Future<bool> registerPushToken({
    required String token,
    required String platform,
    String? deviceId,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/notifications/push-token'),
      headers: await _headers(),
      body: jsonEncode({
        'token': token,
        'platform': platform,
        if (deviceId != null) 'device_id': deviceId,
      }),
    );

    return response.statusCode == 200;
  }

  static Future<bool> unregisterPushToken({required String token}) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/notifications/push-token'),
      headers: await _headers(),
      body: jsonEncode({'token': token}),
    );

    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>?> fetchCallToken({
    required String channel,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/calls/token'),
      headers: await _headers(),
      body: jsonEncode({'channel': channel}),
    );

    if (response.statusCode != 200) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> fetchMe() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/me'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final user = body['user'] as Map<String, dynamic>?;
    if (user == null) return null;
    final profile = body['profile'];
    final memberships = body['memberships'];
    if (profile is Map) {
      final existing = user['profile'];
      if (existing is Map) {
        user['profile'] = {
          ...Map<String, dynamic>.from(existing),
          ...Map<String, dynamic>.from(profile),
        };
      } else {
        user['profile'] = Map<String, dynamic>.from(profile);
      }
    }
    if (memberships is List) {
      user['memberships'] = memberships
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    }
    cacheMe(user);
    return user;
  }

  static Future<Map<String, dynamic>?> fetchInstitutionPaymentSettings() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/institutions/me/payment-settings'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['settings'] as Map<String, dynamic>?;
  }

  static Future<bool> updateInstitutionPaymentSettings(
    Map<String, dynamic> payload,
  ) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/institutions/me/payment-settings'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );

    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>?> fetchInstitutionEmailSettings() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/institutions/me/email-settings'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['settings'] as Map<String, dynamic>?;
  }

  static Future<bool> updateInstitutionEmailSettings(
    Map<String, dynamic> payload,
  ) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/institutions/me/email-settings'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );

    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>?> updateMe(
    Map<String, dynamic> payload,
  ) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/me'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final user = body['user'] as Map<String, dynamic>?;
    if (user == null) return null;
    final profile = body['profile'];
    if (profile is Map) {
      final existing = user['profile'];
      if (existing is Map) {
        user['profile'] = {
          ...Map<String, dynamic>.from(existing),
          ...Map<String, dynamic>.from(profile),
        };
      } else {
        user['profile'] = Map<String, dynamic>.from(profile);
      }
    }
    return user;
  }

  static Future<void> logout() async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/logout'),
      headers: await _headers(),
    );
  }

  static Future<Map<String, dynamic>?> exportMyData() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/me/export'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<bool> deleteMyAccount() async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/me'),
      headers: await _headers(),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> fetchJobs({
    String? query,
    String? category,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    if (category != null && category.trim().isNotEmpty && category != 'All') {
      params['category'] = category.trim();
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/jobs',
    ).replace(queryParameters: params);
    final response = await http.get(uri, headers: await _headers());

    if (response.statusCode != 200) {
      return {'data': <Map<String, dynamic>>[], 'meta': null};
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return {'data': data.cast<Map<String, dynamic>>(), 'meta': body['meta']};
  }

  static Future<bool> applyToJob({
    required int jobId,
    required String name,
    required String email,
    String? phone,
    String? linkedinUrl,
    required String resumeUrl,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/jobs/$jobId/apply'),
      headers: await _headers(),
      body: jsonEncode({
        'name': name,
        'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (linkedinUrl != null && linkedinUrl.isNotEmpty)
          'linkedin_url': linkedinUrl,
        'resume_url': resumeUrl,
      }),
    );
    return response.statusCode == 201;
  }

  static Future<Map<String, dynamic>?> fetchUserAnalytics() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/analytics/user'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['metrics'] as Map<String, dynamic>?;
  }

  static Future<bool> trackAnalytics({
    required String eventType,
    String? entityType,
    int? entityId,
    double? value,
    Map<String, dynamic>? metadata,
    int? institutionId,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/analytics/track'),
      headers: await _headers(),
      body: jsonEncode({
        'event_type': eventType,
        if (entityType != null) 'entity_type': entityType,
        if (entityId != null) 'entity_id': entityId,
        if (value != null) 'value': value,
        if (metadata != null) 'metadata': metadata,
        if (institutionId != null) 'institution_id': institutionId,
      }),
    );
    return response.statusCode == 201;
  }

  static Future<List<Map<String, dynamic>>> fetchMessageConversations({
    int maxUsers = 20,
  }) async {
    return fetchMessageThreads(limit: maxUsers);
  }

  static Future<int?> fetchUnreadMessageThreadsCount({int limit = 50}) async {
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/api/messages/threads?limit=$limit'),
          headers: await _headers(),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = (body['data'] as List?) ?? const [];
    var total = 0;
    for (final item in rows.whereType<Map>()) {
      final unread = item['unread_count'];
      if (unread is num) {
        total += unread.toInt();
      } else if (unread is String) {
        total += int.tryParse(unread) ?? 0;
      }
    }
    return total;
  }

  static Future<List<Map<String, dynamic>>> fetchMessageThreads({
    int limit = 30,
  }) async {
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/api/messages/threads?limit=$limit'),
          headers: await _headers(),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = (body['data'] as List?) ?? const [];
    return rows.map((item) {
      final row = item as Map<String, dynamic>;
      final user = (row['user'] as Map<String, dynamic>?) ?? {};
      String time = 'now';
      final createdAt = row['last_message_at']?.toString();
      if (createdAt != null) {
        final dt = DateTime.tryParse(createdAt)?.toLocal();
        if (dt != null) {
          final diff = DateTime.now().difference(dt);
          if (diff.inMinutes < 1) {
            time = 'now';
          } else if (diff.inHours < 1) {
            time = '${diff.inMinutes}m';
          } else if (diff.inDays < 1) {
            time = '${diff.inHours}h';
          } else {
            time = '${diff.inDays}d';
          }
        }
      }
      return {
        'user_id': (user['id'] as num?)?.toInt(),
        'name': (user['name'] ?? 'User').toString(),
        'message': (row['last_message'] ?? 'Start a conversation').toString(),
        'time': time,
        'unread': (row['unread_count'] as num?)?.toInt() ?? 0 > 0,
        'type': 'Focused',
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchMessageThread(
    int userId, {
    int perPage = 50,
  }) async {
    final response = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/api/messages/$userId?per_page=$perPage',
          ),
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> sendMessage({
    required int userId,
    required String body,
    int? replyToMessageId,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentName,
    int? attachmentSize,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/messages/$userId'),
      headers: await _headers(),
      body: jsonEncode({
        'body': body,
        if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
        if (attachmentType != null) 'attachment_type': attachmentType,
        if (attachmentName != null) 'attachment_name': attachmentName,
        if (attachmentSize != null) 'attachment_size': attachmentSize,
      }),
    );
    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      payload = null;
    }
    return {
      'ok': response.statusCode == 201,
      'message': payload?['message']?.toString(),
      'data': payload?['data'],
    };
  }

  static Future<List<Map<String, dynamic>>> fetchGroupChats({
    int perPage = 20,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/group-chats?per_page=$perPage'),
      headers: await _headers(),
    );

    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>?> createGroupChat({
    required String name,
    required List<int> memberIds,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/group-chats'),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'member_ids': memberIds}),
    );

    if (response.statusCode != 201) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['group'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> updateGroupChat({
    required int groupId,
    required String name,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/group-chats/$groupId'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['group'] as Map<String, dynamic>?;
  }

  static Future<List<Map<String, dynamic>>> fetchGroupChatMembers(
    int groupId,
  ) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/group-chats/$groupId/members'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  static Future<bool> removeGroupChatMember({
    required int groupId,
    required int userId,
  }) async {
    final response = await http.delete(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/group-chats/$groupId/members/$userId',
      ),
      headers: await _headers(),
    );
    return response.statusCode == 200;
  }

  static Future<List<Map<String, dynamic>>> fetchGroupThread(
    int groupId, {
    int perPage = 50,
  }) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/group-chats/$groupId/messages?per_page=$perPage',
      ),
      headers: await _headers(),
    );

    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  static Future<bool> sendGroupMessage({
    required int groupId,
    required String body,
    int? replyToMessageId,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentName,
    int? attachmentSize,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/group-chats/$groupId/messages'),
      headers: await _headers(),
      body: jsonEncode({
        'body': body,
        if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
        if (attachmentType != null) 'attachment_type': attachmentType,
        if (attachmentName != null) 'attachment_name': attachmentName,
        if (attachmentSize != null) 'attachment_size': attachmentSize,
      }),
    );

    return response.statusCode == 201;
  }

  static Future<bool> reactToDirectMessage({
    required int messageId,
    required String emoji,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/messages/direct/$messageId/react'),
      headers: await _headers(),
      body: jsonEncode({'emoji': emoji}),
    );
    return response.statusCode == 200;
  }

  static Future<bool> reactToGroupMessage({
    required int messageId,
    required String emoji,
  }) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/group-chats/messages/$messageId/react',
      ),
      headers: await _headers(),
      body: jsonEncode({'emoji': emoji}),
    );
    return response.statusCode == 200;
  }

  static Future<String?> fetchChatWallpaper({required String chatKey}) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/chat-preferences/$chatKey'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    return data?['wallpaper']?.toString();
  }

  static Future<bool> updateChatWallpaper({
    required String chatKey,
    required String wallpaper,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/chat-preferences/$chatKey'),
      headers: await _headers(),
      body: jsonEncode({'wallpaper': wallpaper}),
    );
    return response.statusCode == 200;
  }

  static Future<void> sendTypingStatus({required int userId}) async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/messages/$userId/typing'),
      headers: await _headers(),
    );
  }

  static Future<bool> fetchTypingStatus({required int userId}) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/messages/$userId/typing'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return false;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['typing'] == true;
  }

  static Future<void> sendGroupTypingStatus({required int groupId}) async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/group-chats/$groupId/typing'),
      headers: await _headers(),
    );
  }

  static Future<List<int>> fetchGroupTypingStatus({
    required int groupId,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/group-chats/$groupId/typing'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) return [];
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (body['typing_user_ids'] as List?) ?? const [];
    return list.map((e) => (e as num).toInt()).toList();
  }

  static Future<Map<String, dynamic>?> uploadMedia({
    required String filePath,
    String? fileName,
  }) async {
    final token = await AuthSession.getToken();
    final originalFile = File(filePath);
    File? uploadFile = originalFile;
    try {
      final length = await originalFile.length();
      final originalName = fileName ?? originalFile.uri.pathSegments.last;
      final lowerPath = filePath.toLowerCase();
      final lowerName = originalName.toLowerCase();
      bool hasExt(String ext) =>
          lowerPath.endsWith(ext) || lowerName.endsWith(ext);
      final isImage =
          hasExt('.jpg') ||
          hasExt('.jpeg') ||
          hasExt('.png') ||
          hasExt('.webp') ||
          hasExt('.heic') ||
          hasExt('.heif');
      final isAppleFormat = hasExt('.heic') || hasExt('.heif');
      final shouldConvertUnknownIosImage =
          Platform.isIOS &&
          isImage &&
          !hasExt('.png') &&
          !hasExt('.webp') &&
          !hasExt('.jpg') &&
          !hasExt('.jpeg');
      final shouldForceJpeg = isAppleFormat || shouldConvertUnknownIosImage;

      if (isImage && (shouldForceJpeg || length > 2 * 1024 * 1024)) {
        final ext = shouldForceJpeg
            ? '.jpg'
            : (hasExt('.png') ? '.png' : '.jpg');
        final targetPath =
            '${Directory.systemTemp.path}/upload_${DateTime.now().millisecondsSinceEpoch}$ext';
        final compressed = await FlutterImageCompress.compressAndGetFile(
          originalFile.path,
          targetPath,
          quality: 85,
          minWidth: 1440,
          minHeight: 1440,
          format: ext == '.png' ? CompressFormat.png : CompressFormat.jpeg,
        );
        if (compressed != null) {
          uploadFile = File(compressed.path);
          if (ext == '.jpg') {
            fileName = originalName.replaceAll(
              RegExp(r'\.[^.]+$', caseSensitive: false),
              '.jpg',
            );
            if (fileName == originalName) {
              fileName = '$originalName.jpg';
            }
          }
        }
      }
    } catch (_) {
      uploadFile = originalFile;
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/media/upload');
    final request = http.MultipartRequest('POST', uri);
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';
    final file = await http.MultipartFile.fromPath(
      'file',
      uploadFile.path,
      filename: fileName,
    );
    request.files.add(file);
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201 && response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['url'] != null) {
      data['url'] = _normalizeMediaUrl(data['url'].toString());
    }
    return data;
  }

  static Future<Map<String, dynamic>?> createStory({
    required List<Map<String, dynamic>> media,
    String visibility = 'public',
    String? caption,
    int? institutionId,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/stories'),
      headers: await _headers(),
      body: jsonEncode({
        'visibility': visibility,
        'caption': caption,
        if (institutionId != null) 'institution_id': institutionId,
        'media': media,
      }),
    );
    if (response.statusCode != 201) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final story = body['story'] as Map<String, dynamic>?;
    return story == null ? null : _normalizeStory(story);
  }

  static Future<void> viewStory(int storyId) async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/stories/$storyId/view'),
      headers: await _headers(),
    );
  }

  static Future<void> reactStory(int storyId, String emoji) async {
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/stories/$storyId/react'),
      headers: await _headers(),
      body: jsonEncode({'emoji': emoji}),
    );
  }

  static Future<bool> replyToStory({
    required int storyId,
    String? message,
    String? emoji,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/stories/$storyId/reply'),
      headers: await _headers(),
      body: jsonEncode({
        if (message != null) 'message': message,
        if (emoji != null) 'emoji': emoji,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<bool> deleteStory(int storyId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/stories/$storyId');
    final headers = await _headers();
    final response = await http.delete(uri, headers: headers);
    if (response.statusCode >= 200 && response.statusCode < 300) return true;

    // Some environments are stricter with DELETE verbs, so fall back to
    // method override before failing the action for the user.
    final fallback = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/stories/$storyId/delete'),
      headers: headers,
    );
    return fallback.statusCode >= 200 && fallback.statusCode < 300;
  }

  static Future<bool> repostStory(int storyId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/stories/$storyId/repost'),
      headers: await _headers(),
    );
    return response.statusCode == 200;
  }

  static Future<bool> unrepostStory(int storyId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/stories/$storyId/repost'),
      headers: await _headers(),
    );
    return response.statusCode == 200;
  }

  static Future<bool> shareStory(int storyId, {String? channel}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/stories/$storyId/share'),
      headers: await _headers(),
      body: jsonEncode({
        if (channel != null && channel.isNotEmpty) 'channel': channel,
      }),
    );
    return response.statusCode == 200;
  }
}
