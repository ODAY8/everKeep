import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One HTTP request the app sent to "Supabase".
class Recorded {
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final String body;

  Recorded(this.method, this.url, this.headers, this.body);

  String get path => url.path;
  Map<String, String> get query => url.queryParameters;

  /// The JSON body, or null for requests with none.
  dynamic get json => body.isEmpty ? null : jsonDecode(body);

  @override
  String toString() =>
      '$method ${url.path}${url.hasQuery ? '?${url.query}' : ''}';
}

typedef Route = FutureOr<http.Response> Function(Recorded request);

http.Response jsonResponse(Object? body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// A PostgREST/Storage error body, as the real services send them.
http.Response errorResponse(int status, Map<String, Object?> body) =>
    jsonResponse(body, status: status);

/// A GoTrue (Auth) error, in the shape the real server uses:
/// `{"code": <http status>, "error_code": "...", "msg": "..."}`.
http.Response authError(int status, String errorCode, String message) =>
    jsonResponse({
      'code': status,
      'error_code': errorCode,
      'msg': message,
    }, status: status);

/// In-memory stand-in for the storage supabase_flutter provides in the real
/// app (SharedPreferences) so the PKCE sign-in flow can run in tests.
class MemoryAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _items = {};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _items[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _items.remove(key);
  }
}

const String testUserId = '11111111-1111-1111-1111-111111111111';

/// A real [SupabaseClient] wired to an in-memory HTTP layer, so a service can
/// be exercised end to end: the exact requests it makes are recorded, and the
/// responses (including failures) are whatever the test supplies.
class FakeSupabase {
  final List<Recorded> requests = [];
  late final SupabaseClient client;

  /// Answers every non-auth request. Unhandled requests fail the test.
  Route? route;

  /// Answers auth requests. Defaults to a successful email sign-in.
  Route? authRoute;

  FakeSupabase() {
    client = SupabaseClient(
      'https://test.supabase.co',
      'sb_publishable_test',
      httpClient: MockClient((request) async {
        final recorded = Recorded(
          request.method,
          request.url,
          request.headers,
          request.body,
        );
        requests.add(recorded);

        final Route? handler = request.url.path.startsWith('/auth/v1/')
            ? (authRoute ?? _defaultAuth)
            : route;
        if (handler == null) {
          fail('Unexpected request with no route set: $recorded');
        }
        final response = await handler(recorded);

        // Real HTTP clients attach the originating request to every response,
        // and the SDK relies on it (MockClient copies it from what we return).
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryAsyncStorage(),
      ),
    );
    addTearDown(client.dispose);
  }

  /// Signs in through the (mocked) token endpoint, giving the client a real
  /// session — which is how the services see "the signed-in user".
  Future<void> signIn({
    String userId = testUserId,
    String email = 'alex@example.com',
    String name = 'Alex Rivera',
  }) async {
    await client.auth.signInWithPassword(email: email, password: 'secret1');
    // Only count what the test itself triggers.
    requests.clear();
  }

  Iterable<Recorded> where(String method, String pathContains) => requests
      .where((r) => r.method == method && r.path.contains(pathContains));

  Recorded single(String method, String pathContains) {
    final matches = where(method, pathContains).toList();
    expect(
      matches,
      hasLength(1),
      reason: 'expected exactly one $method *$pathContains* but saw: $requests',
    );
    return matches.single;
  }

  Route get _defaultAuth => (request) {
    if (request.path.endsWith('/token')) return sessionResponse();
    return jsonResponse({});
  };
}

/// A GoTrue session payload for [userId].
http.Response sessionResponse({
  String userId = testUserId,
  String email = 'alex@example.com',
  String name = 'Alex Rivera',
  bool emailConfirmed = true,
}) {
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  return jsonResponse({
    'access_token': fakeJwt(userId: userId, exp: exp),
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': exp,
    'refresh_token': 'refresh-token',
    'user': authUserJson(
      userId: userId,
      email: email,
      name: name,
      emailConfirmed: emailConfirmed,
    ),
  });
}

Map<String, Object?> authUserJson({
  String userId = testUserId,
  String email = 'alex@example.com',
  String name = 'Alex Rivera',
  bool identities = true,
  bool emailConfirmed = true,
}) => {
  'id': userId,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': email,
  if (emailConfirmed) 'email_confirmed_at': '2026-01-01T00:00:00Z',
  'app_metadata': {'provider': 'email'},
  'user_metadata': {'full_name': name},
  'identities': identities
      ? [
          {
            'id': userId,
            'user_id': userId,
            'identity_id': userId,
            'identity_data': {'email': email},
            'provider': 'email',
            'created_at': '2026-01-01T00:00:00Z',
            'last_sign_in_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
          },
        ]
      : <Object?>[],
  'created_at': '2026-01-01T00:00:00Z',
  'last_sign_in_at': '2026-09-20T08:30:00Z',
};

/// An (unsigned) JWT with the claims the client reads.
String fakeJwt({required String userId, required int exp}) {
  String part(Map<String, Object?> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'sub': userId, 'role': 'authenticated', 'aud': 'authenticated', 'exp': exp})}.'
      'signature';
}
