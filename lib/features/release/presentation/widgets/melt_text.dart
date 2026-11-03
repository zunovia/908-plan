import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'rel_styles.dart';

/// 書いた文字が 1 字ずつ氷の青に染まり、にじんで下へ溶けて消える演出（Luckarise の MeltText を移植）。
/// 全体で約 4 秒（文字数が多いと少し長い）。「アニメーションを減らす」では 1 秒のフェードだけにする。
/// 燃やす・壊す表現は使わない。
class MeltText extends StatefulWidget {
  const MeltText({super.key, required this.text, this.startDelay = const Duration(milliseconds: 350), this.onFinished});

  /// 溶かす文字（300 字まで）。
  final String text;

  /// 始まるまでの間。
  final Duration startDelay;

  /// 溶け終わったとき。
  final VoidCallback? onFinished;

  static const int maxChars = 300;

  @override
  State<MeltText> createState() => _MeltTextState();
}

class _MeltTextState extends State<MeltText> with TickerProviderStateMixin {
  static const int _meltMs = 2600;
  static const int _fadeMs = 1000;

  AnimationController? _controller;
  late List<String> _chars;
  late List<int> _delays;
  bool _reduce = false;
  int _durationMs = _meltMs;
  int _totalMs = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) _setup();
  }

  @override
  void didUpdateWidget(MeltText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller?.dispose();
      _controller = null;
      _setup();
    }
  }

  void _setup() {
    _reduce = relReduceMotion(context);
    final runes = widget.text.runes.take(MeltText.maxChars).toList();
    _chars = runes.map(String.fromCharCode).toList();
    final seed = widget.text.hashCode;
    _delays = [
      for (var i = 0; i < _chars.length; i++) _reduce ? 0 : Random(i * 31 + seed).nextInt(1200) + i * 8,
    ];
    _durationMs = _reduce ? _fadeMs : _meltMs;
    final maxDelay = _delays.isEmpty ? 0 : _delays.reduce(max);
    _totalMs = widget.startDelay.inMilliseconds + maxDelay + _durationMs + 200;
    final c = AnimationController(vsync: this, duration: Duration(milliseconds: _totalMs));
    c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onFinished?.call();
    });
    _controller = c..forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = RelPalette.of(context);
    final controller = _controller!;
    final style = RelStyles.body.copyWith(fontSize: 17, height: 1.6);
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final nowMs = controller.value * _totalMs - widget.startDelay.inMilliseconds;
          return Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < _chars.length; i++) _char(i, nowMs, style, p),
            ],
          );
        },
      ),
    );
  }

  Widget _char(int i, double nowMs, TextStyle style, RelPalette p) {
    final raw = ((nowMs - _delays[i]) / _durationMs).clamp(0.0, 1.0);
    final progress = Curves.fastOutSlowIn.transform(raw);
    final double colorT;
    final double fade;
    if (_reduce) {
      colorT = progress;
      fade = progress;
    } else {
      colorT = (progress / 0.35).clamp(0.0, 1.0);
      fade = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    }
    Widget w = Text(
      _chars[i],
      style: style.copyWith(color: Color.lerp(p.text, p.ice, colorT)),
    );
    if (!_reduce && fade > 0) {
      final sigma = 3.0 * fade;
      w = Transform.translate(
        offset: Offset(0, 26 * fade),
        child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: w),
      );
    }
    return Opacity(opacity: 1 - fade, child: w);
  }
}
