import 'package:material_ui/material_ui.dart';

import 'package:pipefader_gui/state/app_model.dart';
import 'package:pipefader_gui/core/theme.dart';

const double _rulerWidth = 92;
const double _rulerHeight = 160;
const double _tempoStep = 0.00022;
const double _bendStep = 0.0009;

/// Wraps the deck-info tempo readout. Vertical drag changes tempo, horizontal
/// drag bends, and a tap pins the BPM ruler; dragging without a pinned ruler
/// shows it only while the finger is down. The ruler floats to the left of the
/// readout so the layout never changes height.
class TempoControl extends StatefulWidget {
  const TempoControl({
    required this.model,
    required this.deck,
    required this.child,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final Widget child;

  @override
  State<TempoControl> createState() => _TempoControlState();
}

class _TempoControlState extends State<TempoControl> {
  final _link = LayerLink();
  OverlayEntry? _entry;
  bool _pinned = false;
  double _bend = 0;

  @override
  void dispose() {
    _removeRuler();
    super.dispose();
  }

  void _showRuler() {
    if (_entry != null) return;
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        width: _rulerWidth,
        height: _rulerHeight,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topRight,
          offset: const Offset(-4, 4),
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeRuler,
              onVerticalDragUpdate: (details) => widget.model.adjustTempo(
                widget.deck,
                -details.delta.dy * _tempoStep,
              ),
              child: AnimatedBuilder(
                animation: widget.model,
                builder: (context, _) => TempoRuler(bpm: widget.deck.bpm),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    _entry = entry;
  }

  void _removeRuler() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
  }

  void _togglePinned() {
    if (_pinned) {
      _closeRuler();
    } else {
      _pinned = true;
      _showRuler();
    }
  }

  void _closeRuler() {
    _pinned = false;
    _removeRuler();
  }

  void _startTempoDrag() {
    if (!_pinned) _showRuler();
  }

  void _endTempoDrag() {
    if (!_pinned) _removeRuler();
  }

  void _startBend() => _bend = 0;

  void _updateBend(double dx) {
    _bend += dx * _bendStep;
    widget.model.setNudge(widget.deck, _bend);
  }

  void _endBend() {
    _bend = 0;
    widget.model.releaseBend(widget.deck);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePinned,
          onVerticalDragStart: (_) => _startTempoDrag(),
          onVerticalDragUpdate: (details) => widget.model.adjustTempo(
            widget.deck,
            -details.delta.dy * _tempoStep,
          ),
          onVerticalDragEnd: (_) => _endTempoDrag(),
          onVerticalDragCancel: _endTempoDrag,
          onHorizontalDragStart: (_) => _startBend(),
          onHorizontalDragUpdate: (details) => _updateBend(details.delta.dx),
          onHorizontalDragEnd: (_) => _endBend(),
          onHorizontalDragCancel: _endBend,
          child: widget.child,
        ),
      ),
    );
  }
}

/// The vertical BPM scale shown while the tempo readout is being dragged or
/// pinned: ±2.4 BPM with 0.1 BPM ticks and the current BPM on the accent line.
class TempoRuler extends StatelessWidget {
  const TempoRuler({required this.bpm, super.key});

  final double bpm;

  @override
  Widget build(BuildContext context) {
    final labelStyle = DefaultTextStyle.of(context).style
        .copyWith(fontSize: T.s9, color: T.dim, height: 1);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: T.scrim.withValues(alpha: 0.94),
        border: Border.all(color: T.line),
        boxShadow: const [
          BoxShadow(color: T.shadowSoft, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: CustomPaint(
        painter: _TempoRulerPainter(bpm, labelStyle),
        size: Size.infinite,
      ),
    );
  }
}

class _TempoRulerPainter extends CustomPainter {
  _TempoRulerPainter(this.bpm, this.labelStyle);

  final double bpm;
  final TextStyle labelStyle;

  static const _span = 2.4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final height = size.height;
    final centre = height / 2;
    final first = ((bpm - _span) * 10).floor() / 10;
    final last = ((bpm + _span) * 10).ceil() / 10;
    final minor = Paint()
      ..color = T.dim.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = T.text.withValues(alpha: 0.8)
      ..strokeWidth = 1;

    for (var tick = first; tick <= last + 0.001; tick += 0.1) {
      final y = centre - (tick - bpm) / _span * (height / 2);
      if (y < 0 || y > height) continue;
      final isMajor = (tick * 10).round() % 10 == 0;
      canvas.drawLine(
        Offset(size.width - (isMajor ? 12 : 6), y),
        Offset(size.width, y),
        isMajor ? major : minor,
      );
      if (isMajor) {
        final label = tick.round().toString();
        final text = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          Offset(size.width - 16 - text.width, y - text.height / 2),
        );
      }
    }
    canvas.drawLine(
      Offset(size.width - 18, centre),
      Offset(size.width, centre),
      Paint()
        ..color = T.accent
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_TempoRulerPainter old) =>
      old.bpm != bpm || old.labelStyle != labelStyle;
}
