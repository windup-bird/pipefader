import 'package:material_ui/material_ui.dart';

import 'layout/app_shell.dart';
import 'theme.dart';

void main() {
  runApp(const PipefaderApp());
}

class PipefaderApp extends StatelessWidget {
  const PipefaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pipefader',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => DefaultTextStyle.merge(
        style: const TextStyle(fontSize: T.s13, height: 1.2, color: T.text),
        child: child!,
      ),
      home: const Material(
        type: MaterialType.transparency,
        child: AppShell(),
      ),
    );
  }
}
