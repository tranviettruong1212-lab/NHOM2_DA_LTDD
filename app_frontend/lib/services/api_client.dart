import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'API $statusCode: $message';
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw ApiException(401, 'Bạn cần đăng nhập trước.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Không lấy được Firebase ID token.');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<dynamic> get(String path) async {
    final response = await http.get(_uri(path), headers: await _headers());
    return _decode(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(_uri(path), headers: await _headers(), body: jsonEncode(body));
    return _decode(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await http.put(_uri(path), headers: await _headers(), body: jsonEncode(body));
    return _decode(response);
  }

  Future<void> delete(String path) async {
    final response = await http.delete(_uri(path), headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
    }
  }

  dynamic _decode(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    dynamic data;
    if (body.isNotEmpty) {
      try { data = jsonDecode(body); } catch (_) { data = body; }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Yêu cầu thất bại.';
      if (data is Map) {
        message = (data['error'] ?? data['message'] ?? data['title'] ?? message).toString();
      } else if (data is String && data.isNotEmpty) {
        message = data;
      }
      if (response.statusCode == 401) message = 'Phiên đăng nhập không hợp lệ. Hãy đăng nhập lại.';
      if (response.statusCode == 403) message = 'Bạn không có quyền thực hiện thao tác này.';
      throw ApiException(response.statusCode, message);
    }
    return data;
  }
}
