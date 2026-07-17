import 'dart:async';
import 'package:flutter/material.dart';

class GaiaAvatar extends StatefulWidget {
  final double radius;
  const GaiaAvatar({super.key, this.radius = 16});

  @override
  State<GaiaAvatar> createState() => _GaiaAvatarState();
}

class _GaiaAvatarState extends State<GaiaAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isBlinking = false;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    // Pulse animation (gentle breathing effect)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Periodical blink timer (blinks every 4 seconds)
    _blinkTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() => _isBlinking = true);
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            setState(() => _isBlinking = false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = widget.radius * 2;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withBlue(210).withGreen(170), // Elegant wellness gradient
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.35),
              blurRadius: 5,
              spreadRadius: 0.5,
              offset: const Offset(0, 1.5),
            )
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Eyes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 75),
                    width: widget.radius * 0.28,
                    height: _isBlinking ? 1.5 : widget.radius * 0.28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(widget.radius * 0.14),
                    ),
                  ),
                  SizedBox(width: widget.radius * 0.26),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 75),
                    width: widget.radius * 0.28,
                    height: _isBlinking ? 1.5 : widget.radius * 0.28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(widget.radius * 0.14),
                    ),
                  ),
                ],
              ),
              SizedBox(height: widget.radius * 0.15),
              // Smile
              Container(
                width: widget.radius * 0.46,
                height: widget.radius * 0.2,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(widget.radius * 0.23),
                    bottomRight: Radius.circular(widget.radius * 0.23),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
