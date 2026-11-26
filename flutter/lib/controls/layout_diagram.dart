import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/core/layout_mode.dart';

/// A small schematic of a layout: one frame with the band dividers inside it,
/// not a pile of separate boxes. Deck info splits across the width (or down the
/// page on the stacked face); control, browser and waveform read as bands.
class LayoutDiagram extends StatelessWidget {
  const LayoutDiagram({
    required this.mode,
    required this.color,
    this.size = const Size(46, 28),
    super.key,
  });

  final LayoutMode mode;
  final Color color;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: size, painter: _LayoutDiagramPainter(mode, color));
  }
}

class _Band {
  const _Band(this.top, this.bottom, this.alpha);

  final double top;
  final double bottom;
  final double alpha;
}

class _Divider {
  const _Divider(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;
}

class _Grid {
  const _Grid({required this.bands, required this.dividers});

  final List<_Band> bands;
  final List<_Divider> dividers;
}

class _LayoutDiagramPainter extends CustomPainter {
  _LayoutDiagramPainter(this.mode, this.color);

  final LayoutMode mode;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size.height * 0.045)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.85);
    final grid = _grid();
    for (final band in grid.bands) {
      canvas.drawRect(
        Rect.fromLTRB(
          0.03 * size.width,
          band.top * size.height,
          0.97 * size.width,
          band.bottom * size.height,
        ),
        Paint()..color = color.withValues(alpha: band.alpha),
      );
    }
    // The frame is the only closed rectangle; everything else is a divider.
    canvas.drawRect(
      Rect.fromLTRB(
        0.03 * size.width,
        0.02 * size.height,
        0.97 * size.width,
        0.98 * size.height,
      ),
      stroke,
    );
    for (final line in grid.dividers) {
      canvas.drawLine(
        Offset(line.left * size.width, line.top * size.height),
        Offset(line.right * size.width, line.bottom * size.height),
        stroke,
      );
    }
  }

  _Grid _grid() => switch (mode) {
    LayoutMode.full => const _Grid(
      bands: [_Band(0.22, 0.46, 0.30), _Band(0.46, 0.98, 0.07)],
      dividers: [
        _Divider(0.03, 0.22, 0.97, 0.22),
        _Divider(0.03, 0.46, 0.97, 0.46),
        _Divider(0.50, 0.02, 0.50, 0.22),
      ],
    ),
    LayoutMode.landscape => const _Grid(
      bands: [_Band(0.46, 0.98, 0.30)],
      dividers: [
        _Divider(0.03, 0.46, 0.97, 0.46),
        _Divider(0.50, 0.02, 0.50, 0.46),
      ],
    ),
    LayoutMode.stacked => const _Grid(
      bands: [_Band(0.56, 0.98, 0.30)],
      dividers: [
        _Divider(0.03, 0.30, 0.97, 0.30),
        _Divider(0.03, 0.56, 0.97, 0.56),
      ],
    ),
    LayoutMode.allInOne => const _Grid(
      bands: [_Band(0.22, 0.68, 0.14), _Band(0.68, 0.98, 0.30)],
      dividers: [
        _Divider(0.03, 0.22, 0.97, 0.22),
        _Divider(0.03, 0.68, 0.97, 0.68),
        _Divider(0.50, 0.02, 0.50, 0.22),
      ],
    ),
  };

  @override
  bool shouldRepaint(_LayoutDiagramPainter old) =>
      old.mode != mode || old.color != color;
}
