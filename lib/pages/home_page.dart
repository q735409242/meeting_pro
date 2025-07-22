// ignore_for_file: non_constant_identifier_names
// lib/pages/home_page.dart

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/material.dart';
import 'package:test_rtc/api/api.dart';
import '../utils/call_initializer.dart';
import 'call_page.dart';
import '../../widgets/dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';  // 导入 Platform 类
import 'package:device_info_plus/device_info_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _registrationCode;
  String? _deviceId;
  String? _roomId;
  String? _appId_cf;
  String? _certificate_cf;
  String? _appId_sdk;
  String? _certificate_sdk;
  String? _type;
  String? _channel;

  @override
  void initState() {
    super.initState();
    // 延迟到首帧后再初始化权限（不需要 UI 也可去掉这行）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions(showOnFailure: false);
    });
    _loadRegistrationInfo();
  }

  /// 加载注册码和设备 ID
  Future<void> _loadRegistrationInfo() async {
    // 这里可以从本地存储或其他地方加载注册码和设备 ID
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _registrationCode = prefs.getString('registration_code');
      _deviceId = prefs.getString('device_id');
    });
  }

  /// 调用纯逻辑初始化；失败时弹框引导
  Future<bool> _checkPermissions({bool showOnFailure = true}) async {
    final ok = await CallInitializer.initialize();
    print('权限检查结果: $ok');
    if (!ok && showOnFailure && mounted) {
      await _showPermissionDialog();
    }
    return ok;
  }

  /// 弹框让用户去设置页手动打开权限
  Future<void> _showPermissionDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
        builder: (_) {
          String contentText;
          if (Platform.isAndroid) {
            // Android 平台
            contentText = '请在系统设置中开启 麦克风/电话/通知 等权限';
          } else if (Platform.isIOS) {
            // iOS 平台
            contentText = '请在系统设置中开启 麦克风/本地网络 权限';
          } else {
            // 其他平台
            contentText = '请在系统设置中开启相关权限';
          }

          return AlertDialog(
            title: const Text('权限不足'),
            content: Text(contentText),  // 根据平台显示不同的提示内容
            actions: [
              TextButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.of(context).pop();
                },
                child: const Text('前往设置'),
              ),
            ],
          );
        }
    );
  }

  /// 生成随机房间号
  // String _genRoomId() => List.generate(4, (_) => Random().nextInt(10)).join();

  /// 点击“创建”或“加入”时先检查权限，通过再跳转
  Future<void> _enterCall(String roomId, bool isCaller, String type,
      String channel) async {
    if (!await _checkPermissions()) return;
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CallPage(
                roomId: roomId,
                isCaller: isCaller,
                registrationCode: _registrationCode,
                appid_cf: _appId_cf,
                certificate_cf: _certificate_cf,
                appid_sdk: _appId_sdk,
                certificate_sdk: _certificate_sdk,
                deviceId: _deviceId,
                type: _type,
                channel: channel),
      ),
    );
  }

  Future<void> _handleBindOnly() async {
    // 获取设备信息
    final deviceInfoPlugin = DeviceInfoPlugin();
    String deviceId = 'APP${DateTime.now().millisecondsSinceEpoch}';

    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
        deviceId = 'APP_${androidInfo.manufacturer}_${androidInfo.model}_v${androidInfo.version.release}_$deviceId';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
        deviceId = 'APP_${iosInfo.name}_${iosInfo.model}_v${iosInfo.systemVersion}_$deviceId';
      }
    } catch (e) {
      print("Failed to get device info: $e");
      deviceId = 'APP_UNKNOWN_DEVICE_${DateTime.now().millisecondsSinceEpoch}';
    }
    if (!mounted) return; // 确保 Widget 还在树中
    final code = await showBindCodeDialog(context);
    final ret = await Api.bindCode(code!, deviceId);
    print('绑定结果：$ret');
    if (ret['msg'] == '绑定成功') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('registration_code', code);
      await prefs.setString('device_id', deviceId);
      setState(() {
        _registrationCode = code;
        _deviceId = deviceId;
      });
      await EasyLoading.showToast('绑定成功');
    } else {
      await EasyLoading.showToast(ret['msg'] ?? '绑定失败');
    }
  }

  Future<void> _handleBindOrUnbind() async {
    if (_registrationCode != null) {
      // 已绑定 → 确认解绑
      final confirmed =
      await showUnbindConfirmDialog(context, _registrationCode!);

      if (confirmed == true) {
        final response = await Api.unbindCode(_registrationCode!);
        print('解绑结果：$response');
        if (response['msg'] == '解绑成功') {
          await EasyLoading.showToast('解绑成功');
        } else {
          await EasyLoading.showToast(response['msg'] ?? '解绑失败');
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('registration_code');
        await prefs.remove('device_id');
        setState(() {
          _registrationCode = null;
          _deviceId = null;
        });
      }
    } else {
      // 未绑定 → 跑绑定流程
      await _handleBindOnly();
    }
  }

  /// 创建房间流程
  /// 1. 校验注册码和设备ID是否已绑定
  /// 2. 调用API创建房间，记录请求与响应日志
  /// 3. 解析返回的房间ID、AppID、certificate等信息
  /// 4. 跳转至通话页面或弹出错误提示
  Future<void> _handleCreat() async {
    if (_registrationCode != null && _deviceId != null) {

      _channel = 'cf';
      try {
        print(
            '开始创建房间，注册码: $_registrationCode, 设备ID: $_deviceId');
        final ret =
        await Api.createRoom(_registrationCode!, _deviceId!, _channel!);
        print('创建房间API响应: $ret');

        // 检查API返回消息与数据
        if (ret['msg'] == '' && ret['data'] != null) {
          _roomId = ret['data']['room_id'];
          _appId_cf = ret['data']['appid1'];
          _certificate_cf = ret['data']['certificate1'];
          _appId_sdk = ret['data']['appid2'];
          _certificate_sdk = ret['data']['certificate2'];
          // _appId_sdk='9a15a82acad1487eb5af01a170f605e0';
          // _certificate_sdk='30898e2c67684dfb9ba47bf60c2cc677';

          _type = ret['data']['type'];
          print(
              '房间信息提取成功, room_id: $_roomId, appid1: $_appId_cf, certificate1: $_certificate_cf, appid2: $_appId_sdk, certificate2: $_certificate_sdk,type: ${ret['data']['type']}');
          if (_roomId != null && mounted) {
            _enterCall(_roomId!, true, _type!, _channel!);
          } else {
            print('房间信息获取失败，无法进入通话');
            await EasyLoading.showToast('房间信息获取失败，无法进入通话');
          }
        } else {
          print('创建房间失败，msg: ${ret['msg']}');
          await EasyLoading.showToast(ret['msg'] ?? '创建房间失败');
        }
      } catch (e) {
        print('创建房间异常: $e');
        await EasyLoading.showToast('网络错误,请切换网络或开关飞行模式后重试');
      }
    } else {
      print('未绑定注册码或设备ID，无法创建房间');
      await EasyLoading.showToast('请先绑定注册码');
    }
  }

  /// 加入房间流程
  /// 1. 调用API加入指定房间，输出API请求与响应日志
  /// 2. 解析返回的AppID、certificate等信息
  /// 3. 跳转至通话页面或弹出错误提示
  Future<void> _handleJoin(String roomid) async {
    try {
      print('开始加入房间，roomid: $roomid');
      final ret = await Api.joinRoom(roomid);
      print('加入房间API响应: $ret');

      // 检查API返回消息与数据
      if (ret['msg'] == '' && ret['data'] != null) {
        _appId_cf = ret['data']['appid1'];
        _certificate_cf = ret['data']['certificate1'];
        _appId_sdk = ret['data']['appid2'];
        _certificate_sdk = ret['data']['certificate2'];
        // _appId_sdk='9a15a82acad1487eb5af01a170f605e0';
        // _certificate_sdk='30898e2c67684dfb9ba47bf60c2cc677';
        _channel = ret['data']['channel'];
        if (_channel == '1') {
          _channel = 'sdk';
        } else if (_channel == '2') {
          _channel = 'cf';
        }
        print(
            '加入房间成功, _appId_cf: $_appId_cf, _certificate_cf: $_certificate_cf, _appId_sdk: $_appId_sdk, _certificate_sdk: $_certificate_sdk,_channel: $_channel');
        _enterCall(roomid, false, "", _channel!);
      } else {
        print('加入房间失败，msg: ${ret['msg']}');
        await EasyLoading.showToast(ret['msg'] ?? '加入房间失败');
      }
    } catch (e) {
      print('加入房间异常: $e');
      await EasyLoading.showToast('网络错误,请切换网络或开关飞行模式后重试');
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
                    title: const Text('欢迎使用云协通'),
        centerTitle: true,
        actions: _registrationCode != null
            ? [
          Padding(
              padding: const EdgeInsets.all(15),
              child: Center(child: Text('$_registrationCode')))
        ]
            : null,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
                icon: const Icon(
                  Icons.video_call,
                  size: 70,
                  color: Colors.blue,
                ),
                label: const Text('创建会议'),
                onLongPress: _handleBindOrUnbind,
                onPressed: _handleCreat),
            const SizedBox(height: 150),
            ElevatedButton.icon(
              icon: const Icon(
                Icons.group_add,
                size: 70,
                color: Colors.blue,
              ),
              label: const Text('加入会议'),
              onPressed: () =>
                  showJoinDialog(ctx, (id) {
                    _handleJoin(id);
                  }),
            ),
          ],
        ),
      ),
    );
  }
}
