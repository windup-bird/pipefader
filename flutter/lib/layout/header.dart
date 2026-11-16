import 'package:material_ui/material_ui.dart';

import '../widgets/logo.dart';

/// The header is the mark and nothing else: no name, no toolbar.
class Header extends StatelessWidget {
  const Header({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(child: LogoMark(size: height * 0.75)),
    );
  }
}
