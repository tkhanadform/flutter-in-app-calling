import 'dart:convert';
import 'package:http/http.dart' as http;

class AcceptCreds {
  final String livekitUrl;
  final String token;
  final String roomName;

  AcceptCreds({
    required this.livekitUrl,
    required this.token,
    required this.roomName,
  });
}

class CallService {
  final String baseUrl;
  CallService(this.baseUrl);

  Future<AcceptCreds> accept({
    required String callId,
    required String userId,
    required String userName,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/calls/accept'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'callId': callId, 'userId': userId, 'userName': userName}),
    );

    if (res.statusCode != 200) throw Exception(res.body);

    final json = jsonDecode(res.body);
    
    // Debug: log the full response
    // ignore: avoid_print
    print('🔍 Backend /calls/accept response: $json');
    
    // Parse fields, ensuring they're strings
    final livekitUrl = json['livekitUrl']?.toString() ?? '';
    final tokenRaw = json['token'];
    final roomName = json['roomName']?.toString() ?? '';
    
    // ignore: avoid_print
    print('🔍 Parsed: livekitUrl=$livekitUrl');
    // ignore: avoid_print
    print('🔍 Parsed: token type=${tokenRaw.runtimeType}, value=$tokenRaw');
    // ignore: avoid_print
    print('🔍 Parsed: roomName=$roomName');
    
    // Check if token is actually an object instead of a string
    if (tokenRaw is Map || tokenRaw is List) {
      throw Exception('❌ Backend error: token field is an object/array, not a string. Backend must return a valid JWT token string. Got: $tokenRaw');
    }
    
    final token = tokenRaw?.toString() ?? '';
    
    if (livekitUrl.isEmpty || token.isEmpty || token == '{}' || token == '[]') {
      throw Exception('❌ Backend error: missing or invalid livekitUrl/token. Backend must generate a valid LiveKit JWT token. Response: $json');
    }
    
    return AcceptCreds(
      livekitUrl: livekitUrl,
      token: token,
      roomName: roomName,
    );
  }

  Future<void> end(String callId) async {
    await http.post(
      Uri.parse('$baseUrl/calls/end'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'callId': callId}),
    );
  }
}