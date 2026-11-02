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
      startX: 0.2 + _random.nextDouble() * 0.6, // random horizontal offset (20% to 80%)
    );

    setState(() {
      _reactions.add(item);
    });

    // Remove after 2.2 seconds animation
    Future.delayed(const Duration(milliseconds: 2200), () {
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
  late Animation<double> _opacity;
  late Animation<double> _scale;
  final double _driftX = (Random().nextDouble() - 0.5) * 60; // gentle horizontal sway

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _translateY = Tween<double>(begin: 0, end: -240).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.9), weight: 40),
    ]).animate(_controller);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
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
      bottom: 60,
      left: widget.startX,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final currentX = _driftX * sin(progress * pi);

          return Transform.translate(
            offset: Offset(currentX, _translateY.value),
            child: Transform.scale(
              scale: _scale.value,
              child: Opacity(
                opacity: _opacity.value.clamp(0.0, 1.0),
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 34),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
