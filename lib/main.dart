import 'package:flutter/material.dart';

void main() => runApp(const IpaLabApp());

class IpaLabApp extends StatelessWidget {
  const IpaLabApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'IPA Lab',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff356b58)),
      scaffoldBackgroundColor: const Color(0xfff5f7f3),
      useMaterial3: true,
    ),
    home: const BuildTestPage(),
  );
}

class BuildTestPage extends StatefulWidget {
  const BuildTestPage({super.key});

  @override
  State<BuildTestPage> createState() => _BuildTestPageState();
}

class _BuildTestPageState extends State<BuildTestPage> {
  static const _commit = String.fromEnvironment(
    'BUILD_COMMIT',
    defaultValue: 'local',
  );
  static const _build = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: 'local',
  );
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shortCommit = _commit.length > 7 ? _commit.substring(0, 7) : _commit;
    return Scaffold(
      appBar: AppBar(
        title: const Text('IPA Lab'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 58,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '云端构建测试',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '看到这个页面，说明应用已在当前设备启动。\n'
                    '点击按钮，继续验证触摸和界面更新。',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    elevation: 0,
                    color: colors.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text('互动测试'),
                          const SizedBox(height: 12),
                          Text(
                            '$_count',
                            key: const Key('tap-count'),
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(color: colors.primary),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            key: const Key('increment'),
                            onPressed: () => setState(() => _count++),
                            icon: const Icon(Icons.add),
                            label: const Text('点击 +1'),
                          ),
                          TextButton(
                            key: const Key('reset'),
                            onPressed: () => setState(() => _count = 0),
                            child: const Text('重新测试'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '离线演示 · 无需登录 · 不申请额外权限',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '版本 1.0.0  /  构建 $_build\n源码 $shortCommit',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
