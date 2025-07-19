// ignore_for_file: non_constant_identifier_names
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class Api {
  static const String _primaryDomain = 'https://api.yunkefu.pro';
  static const String _backupDomain = 'https://r39rcywpi1.execute-api.ap-east-1.amazonaws.com/default/meeting';
  static const String _cloudfrontDomain = 'https://dn4o6cflv79o8.cloudfront.net/meeting';

  static Uri _primary(String path) => Uri.parse('$_primaryDomain$path');
  static Uri _backup(String path) => Uri.parse('$_backupDomain$path');
  static Uri _cloudfront(String path) => Uri.parse('$_cloudfrontDomain$path');


  /// 公共方法：主接口失败时自动请求备用接口
  static Future<Map<String, dynamic>> postWithFallback({
    required Uri primaryUrl,
    required Uri backupUrl,
    required Map<String, dynamic> jsonBody,
    Map<String, String>? headers,
  }) async {
    final body = json.encode(jsonBody);
    final finalHeaders = headers ?? {'Content-Type': 'application/json'};

    Future<Map<String, dynamic>> tryPost(Uri url) async {
      try {
        final res = await http.post(url, body: body, headers: finalHeaders).timeout(const Duration(seconds: 10));
        print('请求: ${url.toString()}，响应: ${res.statusCode}');
        if (res.statusCode == 200) {
          return json.decode(utf8.decode(res.bodyBytes));
        }
      } catch (e) {
        print('请求异常: $e');
      }
      return {};
    }

    final result = await tryPost(primaryUrl);
    if (result.isNotEmpty) return result;

    final backupResult = await tryPost(backupUrl);
    if (backupResult.isNotEmpty) return backupResult;

    final cloudfrontResult = await tryPost(_cloudfront(primaryUrl.path));
    if (cloudfrontResult.isNotEmpty) return cloudfrontResult;

    return {'msg': '请求失败，请更换网络或重试', 'data': null};
  }

  /// 绑定注册码
  static Future<Map<String, dynamic>> bindCode(String registrationCode, String deviceId) async {
    EasyLoading.show(status: '绑定中...');
    try {
      return await postWithFallback(
        primaryUrl: _primary('/BindCode'),
        backupUrl: _backup('/BindCode'),
        jsonBody: {
          'registration_code': registrationCode,
          'device_id': deviceId,
        },
      );
    } finally {
      EasyLoading.dismiss();
    }
  }

  /// 解绑注册码
  static Future<Map<String, dynamic>> unbindCode(String registrationCode) async {
    EasyLoading.show(status: '解绑中...');
    try {
      return await postWithFallback(
        primaryUrl: _primary('/UnBindCode'),
        backupUrl: _backup('/UnBindCode'),
        jsonBody: {
          'registration_code': registrationCode,
        },
      );
    } finally {
      EasyLoading.dismiss();
    }
  }

  /// 创建房间
  static Future<Map<String, dynamic>> createRoom(String registrationCode, String deviceId, String channel) async {
    EasyLoading.show(status: '创建房间中...');
    String channelId;
    if (channel == 'sdk') {
      channelId = '1';
    } else if (channel == 'cf') {
      channelId = '2';
    } else {
      return {'msg': '参数错误', 'data': null};
    }

    try {
      return await postWithFallback(
        primaryUrl: _primary('/create_room'),
        backupUrl: _backup('/create_room'),
        jsonBody: {
          'registration_code': registrationCode,
          'device_id': deviceId,
          'channel': channelId,
        },
      );
    } finally {
      EasyLoading.dismiss();
    }
  }

  /// 查询用户信息
  static Future<Map<String, dynamic>> searchUserInfo(String code) async {
    try {
      return await postWithFallback(
        primaryUrl: _primary('/search_user_info'),
        backupUrl: _backup('/search_user_info'),
        jsonBody: {
          'registration_code': code,
        },
      );
    } catch (e) {
      print('searchUserInfo 异常: $e');
      return {'msg': '请求失败或解析错误,请更换网络后重试', 'data': null};
    }
  }

  /// 加入房间
  static Future<Map<String, dynamic>> joinRoom(String roomId) async {
    EasyLoading.show(status: '加入房间中...');
    try {
      return await postWithFallback(
        primaryUrl: _primary('/join_room'),
        backupUrl: _backup('/join_room'),
        jsonBody: {
          'room_id': roomId,
        },
      );
    } finally {
      EasyLoading.dismiss();
    }
  }

  /// 获取声网 token
  static Future<Map<String, dynamic>> get_token(String roomId) async {
    try {
      return await postWithFallback(
        primaryUrl: _primary('/get_token'),
        // primaryUrl: Uri.parse('/get_token'),
        backupUrl: _backup('/get_token'),
        jsonBody: {
          'roomId': roomId,
        },
      );
    } catch (e) {
      print('get_token 异常: $e');
      return {'msg': '请求失败或解析错误,请更换网络后重试', 'data': null};
    }
  }
}