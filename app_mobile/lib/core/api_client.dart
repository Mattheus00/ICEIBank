import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'session.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? body;

  ApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._session);

  final SessionStore _session;
  final http.Client _http = http.Client();

  Future<Map<String, dynamic>> postJson(
    String baseUrl,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    return _request('POST', baseUrl, path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> getJson(
    String baseUrl,
    String path, {
    bool auth = true,
  }) async {
    return _request('GET', baseUrl, path, auth: auth);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String baseUrl,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (auth) {
      final token = await _session.token();
      if (token == null || token.isEmpty) {
        throw ApiException('Sessão expirada. Faça login de novo.', statusCode: 401);
      }
      headers['Authorization'] = 'Bearer $token';
    }

    late http.Response response;
    try {
      if (method == 'GET') {
        response = await _http
            .get(uri, headers: headers)
            .timeout(AppConfig.timeoutHttp);
      } else {
        response = await _http
            .post(
              uri,
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(AppConfig.timeoutHttp);
      }
    } catch (e) {
      throw ApiException('Falha de rede: $e');
    }

    Map<String, dynamic>? decoded;
    if (response.body.isNotEmpty) {
      try {
        final dynamic raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        } else {
          decoded = {'valor': raw};
        }
      } catch (_) {
        decoded = {'raw': response.body};
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? <String, dynamic>{};
    }

    final erro = decoded?['erro']?.toString() ??
        'Erro HTTP ${response.statusCode}';
    throw ApiException(
      erro,
      statusCode: response.statusCode,
      body: decoded,
    );
  }
}
