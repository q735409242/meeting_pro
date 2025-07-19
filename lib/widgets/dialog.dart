import 'package:flutter/material.dart';

/// 弹出房间号输入框
void showJoinDialog(BuildContext context, Function(String) onJoin) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('输入房间号'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: '如：1234'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消')),
        TextButton(
          onPressed: () {
            final id = controller.text.trim();
            if (id.isNotEmpty) {
              Navigator.pop(context);
              onJoin(id);
            }
          },
          child: const Text('加入'),
        )
      ],
    ),
  );
}

/// 弹出绑定注册码输入框
Future<String?> showBindCodeDialog(BuildContext context) async {
  final controller = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('输入注册码'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: '注册码'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    return controller.text.trim();
  }
  return null;
}

/// 弹出解绑确认弹窗
Future<bool> showUnbindConfirmDialog(BuildContext context, String registrationCode) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('解除绑定'),
      content: const Text('确定要解绑注册码？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('确定'),
        ),
      ],
    ),
  ).then((value) => value == true);
}