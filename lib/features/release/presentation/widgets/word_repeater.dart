import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import 'rel_styles.dart';

/// 唱える言葉を中央に大きく出し、回数「n / 目標」と進捗の輪を添える。
/// 輪は呼吸（吸う→止める→吐く）に合わせてゆっくり拡縮する（「アニメーションを減らす」では止める）。
class WordRepeater extends StatefulWidget {
  const WordRepeater({
    super.key,
    required this.word,
    required this.count,
    required this.goal,
    required this.currentWordLabel,
    required this.remainingLabel,
    this.breathIn = 4,
    this.breathHold = 4,
    this.breathOut = 8,
  });

  /// いまの言葉。
  final String word;
  final int count;
  final int goal;

  /// 読み上げ用「現在の言葉」。
  final String currentWordLabel;

  /// 読み上げ用「残り回数」。
  final String remainingLabel;

  /// 呼吸の秒数（設定の 4-4-8）。
  final int breathIn;
  final int breathHold;
  final int breathOut;

  /// The ring at the default text size.
  static const double baseRingSize = 210;

  /// Space between the ring and the word.
  static const double ringPadding = AppSpacing.lg;

  /// Lines the word may use before its font size is reduced.
  static const int maxWordLines = 3;

  /// Smallest font size the word is shrunk to (before text scaling).
  static const double minWordFontSize = 14;

  /// How far the breathing animation enlarges the ring.
  static const double breathScale = 1.08;

  /// Ring diameter: grows with the user's text scale (2x text → 2x ring) but
  /// never past [maxWidth] (the space the scene gives it, leaving room for the
  /// breathing animation). Never below the default size unless the screen
  /// itself is narrower than that.
  static double ringSizeFor({required double textScale, required double maxWidth}) {
    final wanted = baseRingSize * max(1.0, textScale);
    if (!maxWidth.isFinite || maxWidth <= 0) return wanted;
    return min(wanted, maxWidth / breathScale);
  }

  @override
  State<WordRepeater> createState() => _WordRepeaterState();
}

class _WordRepeaterState extends State<WordRepeater> with TickerProviderStateMixin {
  AnimationController? _breath;
  Animation<double>? _scale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(WordRepeater oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.breathIn != widget.breathIn ||
        oldWidget.breathHold != widget.breathHold ||
        oldWidget.breathOut != widget.breathOut) {
      _breath?.dispose();
      _breath = null;
      _sync();
    }
  }

  void _sync() {
    final reduce = relReduceMotion(context);
    if (reduce) {
      _breath?.dispose();
      _breath = null;
      _scale = null;
      return;
    }
    if (_breath != null) return;
    final inS = max(1, widget.breathIn);
    final holdS = max(0, widget.breathHold);
    final outS = max(1, widget.breathOut);
    final c = AnimationController(vsync: this, duration: Duration(seconds: inS + holdS + outS));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: WordRepeater.breathScale).chain(CurveTween(curve: Curves.easeInOut)), weight: inS.toDouble()),
      if (holdS > 0) TweenSequenceItem(tween: ConstantTween(WordRepeater.breathScale), weight: holdS.toDouble()),
      TweenSequenceItem(tween: Tween(begin: WordRepeater.breathScale, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: outS.toDouble()),
    ]).animate(c);
    _breath = c..repeat();
  }

  @override
  void dispose() {
    _breath?.dispose();
    super.dispose();
  }

  static double _fontSize(String word) {
    final n = word.characters.length;
    if (n <= 6) return 40;
    if (n <= 10) return 34;
    if (n <= 14) return 31;
    return 28;
  }

  TextStyle _wordStyle(RelPalette p, double size) => RelStyles.heading.copyWith(
        color: p.text,
        fontSize: size,
        height: (size + 8) / size,
        fontWeight: FontWeight.w400,
      );

  /// Largest font size (from the length-based default downwards) at which the
  /// word fits inside the ring in at most [WordRepeater.maxWordLines] lines, with the
  /// user's [scaler] applied. Falls back to [WordRepeater.minWordFontSize].
  double _fittedFontSize({
    required TextStyle inherited,
    required RelPalette p,
    required double box,
    required TextScaler scaler,
    required TextDirection direction,
  }) {
    var size = _fontSize(widget.word);
    while (size > WordRepeater.minWordFontSize) {
      final painter = TextPainter(
        // Text merges its style into the ambient DefaultTextStyle (letter
        // spacing etc.); measure with the same merged style.
        text: TextSpan(text: widget.word, style: inherited.merge(_wordStyle(p, size))),
        textAlign: TextAlign.center,
        textDirection: direction,
        textScaler: scaler,
        maxLines: WordRepeater.maxWordLines,
        // Same as the Text below (TextOverflow.ellipsis), so "fits" here
        // means "drawn without an ellipsis" there.
        ellipsis: '…',
      )..layout(maxWidth: box);
      final fits = !painter.didExceedMaxLines && painter.height <= box;
      painter.dispose();
      if (fits) return size;
      size -= 2;
    }
    return WordRepeater.minWordFontSize;
  }

  @override
  Widget build(BuildContext context) {
    final p = RelPalette.of(context);
    final goal = widget.goal;
    final progress = goal > 0 ? (widget.count / goal).clamp(0.0, 1.0) : 0.0;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final ringSize = WordRepeater.ringSizeFor(
          textScale: scaler.scale(_fontSize(widget.word)) / _fontSize(widget.word),
          maxWidth: constraints.maxWidth,
        );
        final box = max(1.0, ringSize - 2 * WordRepeater.ringPadding);
        final size = _fittedFontSize(
          inherited: DefaultTextStyle.of(context).style,
          p: p,
          box: box,
          scaler: scaler,
          direction: direction,
        );
        final ring = SizedBox(
          width: ringSize,
          height: ringSize,
          child: CustomPaint(
            painter: _RingPainter(progress: progress, track: p.border, color: p.ice),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(WordRepeater.ringPadding),
                child: Semantics(
                  label: '${widget.currentWordLabel} ${widget.word}',
                  excludeSemantics: true,
                  child: Text(
                    widget.word,
                    textAlign: TextAlign.center,
                    maxLines: WordRepeater.maxWordLines,
                    overflow: TextOverflow.ellipsis,
                    style: _wordStyle(p, size),
                  ),
                ),
              ),
            ),
          ),
        );
        return _withCount(ring, goal);
      },
    );
  }

  Widget _withCount(Widget ring, int goal) {
    final p = RelPalette.of(context);
    final scale = _scale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (scale == null) ring else ScaleTransition(scale: scale, child: ring),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          label: '${widget.remainingLabel} ${max(0, goal - widget.count)}',
          excludeSemantics: true,
          child: Text(
            '${widget.count} / $goal',
            style: RelStyles.body.copyWith(color: p.subText, fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.track, required this.color});

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2, 2 * pi, false, base);
    if (progress > 0) {
      final arc = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.track != track || old.color != color;
}
