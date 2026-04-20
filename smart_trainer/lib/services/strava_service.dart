import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/strava_config.dart';
import '../models/session_result.dart';

const _kAccessToken = 'strava_access_token';
const _kRefreshToken = 'strava_refresh_token';
const _kExpiresAt = 'strava_expires_at';

class StravaService {
  final _dio = Dio();

  Future<bool> get isAuthorized async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kRefreshToken);
  }

  /// Opens the system browser for Strava OAuth and waits for the callback.
  /// Throws if the user denies access or the flow times out.
  Future<void> authorize() async {
    final server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    final redirectUri = 'http://localhost:$port/callback';

    final authUrl = Uri.parse(
      'https://www.strava.com/oauth/authorize'
      '?client_id=$stravaClientId'
      '&redirect_uri=${Uri.encodeComponent(redirectUri)}'
      '&response_type=code'
      '&scope=activity:write',
    );

    await launchUrl(authUrl, mode: LaunchMode.externalApplication);

    String? code;
    await for (final request in server) {
      code = request.uri.queryParameters['code'];
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(
            '<html><body style="font-family:sans-serif;padding:40px">'
            '<h2>Authorization successful</h2>'
            '<p>You can close this tab and return to Smart Trainer.</p>'
            '</body></html>');
      await request.response.close();
      await server.close();
      break;
    }

    if (code == null) throw Exception('Strava authorization denied');
    await _exchangeCode(code, redirectUri);
  }

  Future<void> _exchangeCode(String code, String redirectUri) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'https://www.strava.com/oauth/token',
      data: {
        'client_id': stravaClientId,
        'client_secret': stravaClientSecret,
        'code': code,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      },
    );
    await _saveTokens(response.data!);
  }

  Future<void> _refreshIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = prefs.getInt(_kExpiresAt) ?? 0;
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (nowEpoch < expiresAt - 60) return; // still valid

    final refreshToken = prefs.getString(_kRefreshToken);
    if (refreshToken == null) throw Exception('Not authorized with Strava');

    final response = await _dio.post<Map<String, dynamic>>(
      'https://www.strava.com/oauth/token',
      data: {
        'client_id': stravaClientId,
        'client_secret': stravaClientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
    );
    await _saveTokens(response.data!);
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, data['access_token'] as String);
    await prefs.setString(_kRefreshToken, data['refresh_token'] as String);
    await prefs.setInt(_kExpiresAt, data['expires_at'] as int);
  }

  Future<String> _accessToken() async {
    await _refreshIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccessToken) ?? '';
  }

  Future<void> uploadActivity(SessionResult result) async {
    if (!await isAuthorized) await authorize();
    final token = await _accessToken();
    final tcx = _buildTcx(result);

    final formData = FormData.fromMap({
      'data_type': 'tcx',
      'name': result.workoutName,
      'file': MultipartFile.fromBytes(utf8.encode(tcx),
          filename: 'activity.tcx'),
    });

    final upload = await _dio.post<Map<String, dynamic>>(
      'https://www.strava.com/api/v3/uploads',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    await _pollUpload((upload.data!['id']).toString(), token);
  }

  Future<void> _pollUpload(String uploadId, String token) async {
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 2));
      final r = await _dio.get<Map<String, dynamic>>(
        'https://www.strava.com/api/v3/uploads/$uploadId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final status = r.data!['status'] as String;
      if (status.contains('Your activity is still being processed')) continue;
      if (r.data!['error'] != null) {
        throw Exception('Strava upload error: ${r.data!['error']}');
      }
      return;
    }
  }

  String _buildTcx(SessionResult result) {
    final start = result.date.toUtc();
    final buf = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
          '<TrainingCenterDatabase '
          'xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2" '
          'xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2">')
      ..writeln('  <Activities>')
      ..writeln('    <Activity Sport="Biking">')
      ..writeln('      <Id>${start.toIso8601String()}</Id>')
      ..writeln(
          '      <Lap StartTime="${start.toIso8601String()}">')
      ..writeln(
          '        <TotalTimeSeconds>${result.durationSeconds}</TotalTimeSeconds>')
      ..writeln('        <DistanceMeters>0</DistanceMeters>')
      ..writeln('        <Intensity>Active</Intensity>')
      ..writeln('        <TriggerMethod>Manual</TriggerMethod>')
      ..writeln('        <Track>');

    for (int i = 0; i < result.powerSamples.length; i++) {
      final t = start.add(Duration(seconds: i));
      final watts = result.powerSamples[i];
      final hr = i < result.hrSamples.length ? result.hrSamples[i] : 0;
      buf.writeln('          <Trackpoint>');
      buf.writeln('            <Time>${t.toIso8601String()}</Time>');
      if (hr > 0) {
        buf.writeln(
            '            <HeartRateBpm><Value>$hr</Value></HeartRateBpm>');
      }
      if (watts > 0) {
        buf
          ..writeln('            <Extensions>')
          ..writeln('              <ns3:TPX>')
          ..writeln('                <ns3:Watts>$watts</ns3:Watts>')
          ..writeln('              </ns3:TPX>')
          ..writeln('            </Extensions>');
      }
      buf.writeln('          </Trackpoint>');
    }

    buf
      ..writeln('        </Track>')
      ..writeln('      </Lap>')
      ..writeln('    </Activity>')
      ..writeln('  </Activities>')
      ..writeln('</TrainingCenterDatabase>');
    return buf.toString();
  }
}

final stravaServiceProvider = Provider((_) => StravaService());
