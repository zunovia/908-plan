import 'package:flutter/material.dart';

import '../../../../core/constants/app_durations.dart';

class TextFadeIn extends StatefulWidget {
  final String text;
  final TextStyle style;
  final List<String> highlightWords;
  final Color? highlightColor;

  const TextFadeIn({
    super.key,
    required this.text,
    required this.style,
    this.highlightWords = const [],
    this.highlightColor,
  });

  @override
  State<TextFadeIn> createState() => _TextFadeInState();
}

class _TextFadeInState extends State<TextFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    final totalDuration = Duration(
      milliseconds:
          widget.text.length * AppDurations.charFadeIn.inMilliseconds,
    );
    _controller = AnimationController(
      vsync: this,
      duration: totalDuration,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.style.color ??
        Theme.of(context).colorScheme.onSurface;

    if (widget.highlightWords.isEmpty) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: Text(
          widget.text,
          style: widget.style.copyWith(color: color),
          textAlign: TextAlign.center,
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RichText(
        textAlign: TextAlign.center,
        text: _buildHighlightedSpan(color),
      ),
    );
  }

  TextSpan _buildHighlightedSpan(Color defaultColor) {
    final spans = <TextSpan>[];
    final text = widget.text;
    var currentIndex = 0;

    while (currentIndex < text.length) {
      var matchFound = false;
      for (final word in widget.highlightWords) {
        if (text.startsWith(word, currentIndex)) {
          spans.add(TextSpan(
            text: word,
            style: widget.style.copyWith(
              color: widget.highlightColor ?? defaultColor,
            ),
          ));
          currentIndex += word.length;
          matchFound = true;
          break;
        }
      }
      if (!matchFound) {
        // Find next highlight or end
        var nextHighlight = text.length;
        for (final word in widget.highlightWords) {
          final idx = text.indexOf(word, currentIndex);
          if (idx != -1 && idx < nextHighlight) {
            nextHighlight = idx;
          }
        }
        spans.add(TextSpan(
          text: text.substring(currentIndex, nextHighlight),
          style: widget.style.copyWith(color: defaultColor),
        ));
        currentIndex = nextHighlight;
      }
    }

    return TextSpan(children: spans);
  }
}
