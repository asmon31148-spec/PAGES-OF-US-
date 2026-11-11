import 'dart:math';
import 'package:flutter/material.dart';

class FloatingReactionItem {
  final Key key;
  final String emoji;
  final double startX;

  FloatingReactionItem({
    required this.key,
    required this.emoji,
    required this.startX,
  });
}

class WatchFloatingReactions extends StatefulWidget {
  final Stream<String>? reactionStream;

  const WatchFloatingReactions({super.key, this.reactionStream});

  @override
  State<WatchFloatingReactions> createState() => WatchFloatingReactionsState();
}

class WatchFloatingReactionsState extends State<WatchFloatingReactions> {
  final List<FloatingReactionItem> _reactions = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    widget.reactionStream?.listen((emoji) {
      triggerReaction(emoji);
    });
  }

  void triggerReaction(String emoji) {
    if (!mounted) return;
    final item = FloatingReactionItem(
      key: UniqueKey(),
      emoji: emoji,
      startX: 0.15 + _random.nextDouble() * 0.70, // 15% to 85% horizontal spread
    );

    setState(() {
      _reactions.add(item);
    });

    // Remove after 2.4s animation
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        setState(() {
          _reactions.remove(item);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return IgnorePointer(
      child: Stack(
        children: _reactions.map((item) {
          return _AnimatedReaction(
            key: item.key,
            emoji: item.emoji,
            startX: item.startX * size.width,
          );
        }).toList(),
      ),
    );
  }
}

class _AnimatedReaction extends StatefulWidget {
  final String emoji;
  final double startX;

  const _AnimatedReaction({
    super.key,
    required this.emoji,
    required this.startX,
  });

  @override
  State<_AnimatedReaction> createState() => _AnimatedReactionState();
}

class _AnimatedReactionState extends State<_AnimatedReaction>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translateY;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  final double _swayAmplitude = 25.0 + Random().nextDouble() * 20.0;
  final double _swaySpeed = 2.0 + Random().nextDouble() * 1.5;
  final double _rotation = (Random().nextDouble() - 0.5) * 0.35;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Smooth upward curved translation
    _translateY = Tween<double>(begin: 0, end: -300).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // Bouncy scale-in then settle
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.4).chain(CurveTween(curve: Curves.easeOutBack)), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.05), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 0.85), weight: 40),
    ]).animate(_controller);

    // Romantic glow fade
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInQuad)), weight: 30),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 50,
      left: widget.startX,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final swayX = sin(progress * _swaySpeed * pi) * _swayAmplitude;
          final currentRotation = sin(progress * pi) * _rotation;

          return Transform.translate(
            offset: Offset(swayX, _translateY.value),
            child: Transform.rotate(
              angle: currentRotation,
              child: Transform.scale(
                scale: _scale.value,
                child: Opacity(
                  opacity: _opacity.value.clamp(0.0, 1.0),
                  child: Text(
                    widget.emoji,
                    style: const TextStyle(
                      fontSize: 36,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
