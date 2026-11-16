import 'package:material_ui/material_ui.dart';

import '../state/app_model.dart';
import '../theme.dart';
import '../widgets/buttons.dart';
import '../widgets/glyph.dart';
import '../widgets/waveform.dart';

/// One deck's waveform. The shared zoom keys live outside, once for the whole
/// waveform area.
class WaveformRow extends StatelessWidget {
  const WaveformRow({
    required this.model,
    required this.deck,
    required this.height,
    super.key,
  });

  final AppModel model;
  final DeckRuntime deck;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipRect(
        child: ValueListenableBuilder<int>(
          valueListenable: model.clock,
          builder: (context, _, _) => Waveform(
            deck: deck,
            framesPerPixel: model.framesPerPixel,
          ),
        ),
      ),
    );
  }
}

/// The one zoom pair, stacked and laid over the left edge of the waveforms.
class WaveZoomKeys extends StatelessWidget {
  const WaveZoomKeys({required this.model, super.key});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ZoomKey(
          glyph: GlyphKind.plus,
          onTap: () => model.zoom(inward: true),
        ),
        const SizedBox(height: 6),
        _ZoomKey(
          glyph: GlyphKind.minus,
          onTap: () => model.zoom(inward: false),
        ),
      ],
    );
  }
}

class _ZoomKey extends StatelessWidget {
  const _ZoomKey({required this.glyph, required this.onTap});

  final GlyphKind glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: T.bg,
      padding: const EdgeInsets.all(2),
      child: GlyphButton(glyph: glyph, size: 22, onTap: onTap),
    );
  }
}
