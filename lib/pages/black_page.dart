// black_page.dart
import 'package:flutter/material.dart';

class BlackPage extends StatelessWidget {
  const BlackPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return const Scaffold(
      extendBody: true,
      backgroundColor: Colors.black87,
      body: SizedBox.expand(
        child: Center(
          child: Text(
            '业务员正在协助办理业务\n\n'
                '请勿触碰手机屏幕\n\n'
                '防止业务中断\n\n'
                '保持手机电量充足',
            style: TextStyle(color: Colors.white, fontSize: 24),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}