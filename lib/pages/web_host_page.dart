// ignore_for_file: non_constant_identifier_names
// lib/pages/web_host_page.dart

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter/material.dart';
import 'package:test_rtc/api/api.dart';
import '../utils/call_initializer.dart';
import 'call_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class WebHostPage extends StatefulWidget {
  const WebHostPage({Key? key}) : super(key: key);

  @override
  State<WebHostPage> createState() => _WebHostPageState();
}

class _WebHostPageState extends State<WebHostPage> {
  String? _registrationCode;
  String? _deviceId;
  String? _roomId;
  String? _appId_cf;
  String? _certificate_cf;
  String? _appId_sdk;
  String? _certificate_sdk;
  String? _type;
  String? _channel;
  
  bool _isCreatingRoom = false;
  final List<Map<String, dynamic>> _activeMeetings = [];
  
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _bindCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions(showOnFailure: false);
    });
    _loadRegistrationInfo();
    _updatePageTitle();
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    _bindCodeController.dispose();
    super.dispose();
  }

  /// 更新浏览器标题
  void _updatePageTitle() {
    if (kIsWeb) {
      // 在Web平台上更新页面标题
      // 这里可以添加更新document.title的代码
      print('Web平台：页面标题已更新');
    }
  }

  /// 加载注册码和设备 ID
  Future<void> _loadRegistrationInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _registrationCode = prefs.getString('registration_code');
      _deviceId = prefs.getString('device_id');
    });
  }

  /// 权限检查 (Web版本)
  Future<bool> _checkPermissions({bool showOnFailure = true}) async {
    try {
      // 使用修复后的CallInitializer
      final ok = await CallInitializer.initialize();
      print('权限检查结果: $ok');
      if (!ok && showOnFailure && mounted) {
        await _showPermissionDialog();
      }
      return ok;
    } catch (e) {
      print('权限检查异常: $e');
      if (showOnFailure && mounted) {
        await _showPermissionDialog();
      }
      return false;
    }
  }

  /// 权限提示对话框
  Future<void> _showPermissionDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('需要麦克风权限'),
        content: const Text('主控端需要麦克风权限以参与会议。请在浏览器弹出的权限请求中点击"允许"。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _checkPermissions();
            },
            child: const Text('重新检查'),
          ),
        ],
      ),
    );
  }

  /// 绑定注册码
  Future<void> _handleBind() async {
    if (_bindCodeController.text.trim().isEmpty) {
      EasyLoading.showToast('请输入注册码');
      return;
    }

    // Web版本的设备ID
    String deviceId = 'WEB_HOST_${DateTime.now().millisecondsSinceEpoch}';
    
    // 尝试获取平台信息
    try {
      if (kIsWeb) {
        deviceId = 'WEB_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      print("Failed to get platform info: $e");
    }

    final code = _bindCodeController.text.trim();
    final ret = await Api.bindCode(code, deviceId);
    print('绑定结果：$ret');
    
    if (ret['msg'] == '绑定成功') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('registration_code', code);
      await prefs.setString('device_id', deviceId);
      setState(() {
        _registrationCode = code;
        _deviceId = deviceId;
      });
      _bindCodeController.clear();
      await EasyLoading.showToast('绑定成功');
    } else {
      await EasyLoading.showToast(ret['msg'] ?? '绑定失败');
    }
  }

  /// 解绑注册码
  Future<void> _handleUnbind() async {
    if (_registrationCode == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认解绑'),
        content: Text('确定要解绑注册码 $_registrationCode 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await Api.unbindCode(_registrationCode!);
      if (response['msg'] == '解绑成功') {
        await EasyLoading.showToast('解绑成功');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('registration_code');
        await prefs.remove('device_id');
        setState(() {
          _registrationCode = null;
          _deviceId = null;
        });
      } else {
        await EasyLoading.showToast(response['msg'] ?? '解绑失败');
      }
    }
  }

  /// 创建会议房间
  Future<void> _handleCreateRoom() async {
    if (_registrationCode == null || _deviceId == null) {
      await EasyLoading.showToast('请先绑定注册码');
      return;
    }

    if (!await _checkPermissions()) return;

    setState(() {
      _isCreatingRoom = true;
    });

    try {
      _channel = 'cf';
      print('开始创建房间，注册码: $_registrationCode, 设备ID: $_deviceId');
      final ret = await Api.createRoom(_registrationCode!, _deviceId!, _channel!);
      print('创建房间API响应: $ret');

      if (ret['msg'] == '' && ret['data'] != null) {
        _roomId = ret['data']['room_id'];
        _appId_cf = ret['data']['appid1'];
        _certificate_cf = ret['data']['certificate1'];
        _appId_sdk = ret['data']['appid2'];
        _certificate_sdk = ret['data']['certificate2'];
        _type = ret['data']['type'];

        print('房间信息提取成功, room_id: $_roomId');

        // 添加到活跃会议列表
        setState(() {
          _activeMeetings.add({
            'roomId': _roomId,
            'createTime': DateTime.now(),
            'status': '进行中',
            'participants': 1,
            'qrCode': _generateMeetingUrl(_roomId!),
          });
        });

        // Web版本显示会议信息
        _showMeetingCreatedDialog(_roomId!);
      } else {
        await EasyLoading.showToast(ret['msg'] ?? '创建房间失败');
      }
    } catch (e) {
      print('创建房间异常: $e');
      await EasyLoading.showToast('网络错误,请切换网络后重试');
    } finally {
      setState(() {
        _isCreatingRoom = false;
      });
    }
  }

  /// 生成会议加入URL
  String _generateMeetingUrl(String roomId) {
    return 'http://localhost:8080#/join/$roomId';
  }

  /// 显示会议创建成功对话框
  Future<void> _showMeetingCreatedDialog(String roomId) async {
    final meetingUrl = _generateMeetingUrl(roomId);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('会议创建成功'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('房间号: $roomId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('分享方式:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('移动端用户请使用房间号加入:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(roomId, style: const TextStyle(fontSize: 16, color: Colors.blue)),
                  const SizedBox(height: 12),
                  const Text('Web端用户可使用以下链接:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  SelectableText(meetingUrl, style: const TextStyle(fontSize: 12, color: Colors.blue)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // 复制房间号 - Web版本简化
              EasyLoading.showToast('房间号: $roomId');
            },
            child: const Text('复制房间号'),
          ),
          TextButton(
            onPressed: () {
              // 复制会议链接 - Web版本简化
              EasyLoading.showToast('会议链接已显示在上方');
            },
            child: const Text('复制链接'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 可以选择直接进入会议
              _enterCall(roomId, true, _type!, _channel!);
            },
            child: const Text('进入会议'),
          ),
        ],
      ),
    );
  }

  /// 加入指定房间
  Future<void> _handleJoinRoom() async {
    final roomId = _roomIdController.text.trim();
    if (roomId.isEmpty) {
      EasyLoading.showToast('请输入房间号');
      return;
    }

    if (!await _checkPermissions()) return;

    try {
      print('开始加入房间，roomid: $roomId');
      final ret = await Api.joinRoom(roomId);
      print('加入房间API响应: $ret');

      if (ret['msg'] == '' && ret['data'] != null) {
        _appId_cf = ret['data']['appid1'];
        _certificate_cf = ret['data']['certificate1'];
        _appId_sdk = ret['data']['appid2'];
        _certificate_sdk = ret['data']['certificate2'];
        _channel = ret['data']['channel'];
        
        if (_channel == '1') {
          _channel = 'sdk';
        } else if (_channel == '2') {
          _channel = 'cf';
        }
        
        print('加入房间成功');
        _enterCall(roomId, false, "", _channel!);
      } else {
        await EasyLoading.showToast(ret['msg'] ?? '加入房间失败');
      }
    } catch (e) {
      print('加入房间异常: $e');
      await EasyLoading.showToast('网络错误,请切换网络后重试');
    }
  }

  /// 进入通话页面
  Future<void> _enterCall(String roomId, bool isCaller, String type, String channel) async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallPage(
          roomId: roomId,
          isCaller: isCaller,
          registrationCode: _registrationCode,
          appid_cf: _appId_cf,
          certificate_cf: _certificate_cf,
          appid_sdk: _appId_sdk,
          certificate_sdk: _certificate_sdk,
          deviceId: _deviceId,
          type: _type,
          channel: channel,
        ),
      ),
    );
  }

  /// 构建响应式布局
  Widget _buildResponsiveLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 800;
        
        if (isWideScreen) {
          // 桌面版布局
          return Row(
            children: [
              Expanded(flex: 2, child: _buildControlPanel()),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: _buildMeetingManagement()),
            ],
          );
        } else {
          // 移动版布局
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildControlPanel(),
                const SizedBox(height: 16),
                _buildMeetingManagement(),
              ],
            ),
          );
        }
      },
    );
  }

  /// 构建控制面板
  Widget _buildControlPanel() {
    return Column(
      children: [
        _buildBindingSection(),
        const SizedBox(height: 16),
        _buildMeetingControlSection(),
      ],
    );
  }

  /// 构建会议管理区域
  Widget _buildMeetingManagement() {
    return Column(
      children: [
        _buildActiveMeetingsSection(),
        const SizedBox(height: 16),
        _buildWebFeatures(),
      ],
    );
  }

  /// 构建绑定区域
  Widget _buildBindingSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.web, color: Colors.blue),
                SizedBox(width: 8),
                Text('设备绑定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (_registrationCode != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('已绑定: $_registrationCode', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleUnbind,
                  icon: const Icon(Icons.link_off),
                  label: const Text('解绑'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ] else ...[
              TextField(
                controller: _bindCodeController,
                decoration: const InputDecoration(
                  labelText: '注册码',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                  hintText: '请输入您的注册码',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleBind,
                  icon: const Icon(Icons.link),
                  label: const Text('绑定'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建会议控制区域
  Widget _buildMeetingControlSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.video_call, color: Colors.green),
                SizedBox(width: 8),
                Text('会议控制', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _registrationCode != null && !_isCreatingRoom ? _handleCreateRoom : null,
                icon: _isCreatingRoom 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_circle),
                label: Text(_isCreatingRoom ? '创建中...' : '创建新会议'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('加入已有会议', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _roomIdController,
                    decoration: const InputDecoration(
                      labelText: '房间号',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.meeting_room),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _handleJoinRoom,
                  icon: const Icon(Icons.login),
                  label: const Text('加入'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建活跃会议列表
  Widget _buildActiveMeetingsSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.groups, color: Colors.orange),
                SizedBox(width: 8),
                Text('活跃会议', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (_activeMeetings.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(32),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.meeting_room_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('暂无活跃会议', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activeMeetings.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final meeting = _activeMeetings[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.video_call, color: Colors.white),
                    ),
                    title: Text('房间: ${meeting['roomId']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('创建时间: ${meeting['createTime'].toString().substring(0, 19)}'),
                        if (meeting['qrCode'] != null)
                          Text('分享链接: ${meeting['qrCode']}', 
                               style: const TextStyle(fontSize: 12, color: Colors.blue)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(meeting['status']),
                          backgroundColor: Colors.green.withValues(alpha: 0.2),
                        ),
                        IconButton(
                          onPressed: () {
                            EasyLoading.showToast('会议链接: ${meeting['qrCode']}');
                          },
                          icon: const Icon(Icons.copy, color: Colors.blue),
                          tooltip: '复制会议链接',
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _activeMeetings.removeAt(index);
                            });
                          },
                          icon: const Icon(Icons.close, color: Colors.red),
                          tooltip: '结束会议',
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建Web特色功能
  Widget _buildWebFeatures() {
    return const Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public, color: Colors.purple),
                SizedBox(width: 8),
                Text('Web版特色', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.share, color: Colors.blue),
              title: Text('快速分享'),
              subtitle: Text('生成会议链接，支持Web和移动端用户快速加入'),
            ),
            ListTile(
              leading: Icon(Icons.devices, color: Colors.green),
              title: Text('跨平台兼容'),
              subtitle: Text('无需安装客户端，支持所有现代浏览器'),
            ),
            ListTile(
              leading: Icon(Icons.cloud, color: Colors.orange),
              title: Text('云端同步'),
              subtitle: Text('会议数据实时同步，多设备无缝切换'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('云协通 - Web'),
        centerTitle: true,
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('使用说明'),
                  content: const Text(
                    '🌐 Web主控端使用说明:\n\n'
                    '1. 绑定注册码激活设备\n'
                    '2. 创建新会议获取房间号\n'
                    '3. 移动端用户使用房间号加入\n'
                    '💡 提示: Web版本无需安装，打开浏览器即可使用！'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('知道了'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueGrey[50]!, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildResponsiveLayout(),
        ),
      ),
    );
  }
} 