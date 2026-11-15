import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app/config.dart';
import '../models/climate_analysis.dart';

enum ApiErrorKind { connection, timeout, http, invalidResponse }

/// A user-presentable failure from the backend call.
class ApiException implements Exception {
  const ApiException(this.kind, this.message, {this.statusCode});

  final ApiErrorKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Talks to the Stone to Stars FastAPI backend.
class ClimateApiService {
  ClimateApiService({
    http.Client? client,
    this.baseUrl = apiBaseUrl,
    this.timeout = requestTimeout,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  /// `GET /api/v1/analysis/climate`.
  Future<ClimateAnalysis> fetchAnalysis({
    required double latitude,
    required double longitude,
    required int startYear,
    required int endYear,
  }) async {
    final base = Uri.parse(baseUrl);
    final uri = base.replace(
      path:
          '${base.path.replaceAll(RegExp(r'/+$'), '')}/api/v1/analysis/climate',
      queryParameters: {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'start_year': '$startYear',
        'end_year': '$endYear',
      },
    );

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw ApiException(
        ApiErrorKind.timeout,
        'The request timed out after ${timeout.inSeconds} s. NASA POWER may be '
        'slow or the backend unreachable.',
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        ApiErrorKind.connection,
        'Could not reach the backend at $baseUrl. Is it running? (${e.message})',
      );
    } catch (e) {
      throw ApiException(
        ApiErrorKind.connection,
        'Could not reach the backend at $baseUrl. ($e)',
      );
    }

    if (response.statusCode != 200) {
      throw ApiException(
        ApiErrorKind.http,
        _errorDetail(response),
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Response is not a JSON object.');
      }
      return ClimateAnalysis.fromJson(decoded);
    } on FormatException catch (e) {
      throw ApiException(
        ApiErrorKind.invalidResponse,
        'The backend returned an unexpected response. ${e.message}',
      );
    } on TypeError {
      // Nested JSON collections can fail their element casts while parsing.
      // This is a response-shape failure, not a network connection failure.
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'The backend returned an unexpected response. '
        'Some climate records have the wrong structure.',
      );
    }
  }

  void close() => _client.close();

  /// Extracts FastAPI's `detail` (string, or list of validation errors).
  String _errorDetail(http.Response response) {
    var detail = 'The backend returned HTTP ${response.statusCode}.';
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final d = body is Map<String, dynamic> ? body['detail'] : null;
      if (d is String) {
        detail = d;
      } else if (d is List && d.isNotEmpty) {
        detail = d
            .map((e) => e is Map ? '${e['loc']?.last}: ${e['msg']}' : '$e')
            .join('; ');
      }
    } catch (_) {
      // keep generic message
    }
    return 'Request failed (HTTP ${response.statusCode}): $detail';
  }
}
