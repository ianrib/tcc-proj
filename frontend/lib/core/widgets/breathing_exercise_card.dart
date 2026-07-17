import 'dart:async';
import 'package:flutter/material.dart';
import 'gaia_avatar.dart';

class BreathingExerciseCard extends StatefulWidget {
  final VoidCallback onClose;
  const BreathingExerciseCard({super.key, required this.onClose});

  @override
  State<BreathingExerciseCard> createState() => _BreathingExerciseCardState();
}

class _BreathingExerciseCardState extends State<BreathingExerciseCard> {
  Timer? _timer;
  String _phase = 'Inalar'; // 'Inalar', 'Segurar', 'Exalar'
  int _secondsCounter = 1;
  bool _showNumber = false;
  int _cycleCount = 1;

  @override
  void initState() {
    super.initState();
    _startExercise();
  }

  void _startExercise() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;
      setState(() {
        _showNumber = !_showNumber;
        // Every 1 second (two 500ms ticks), increment the counter
        if (!_showNumber) {
          if (_secondsCounter < 5) {
            _secondsCounter++;
          } else {
            _secondsCounter = 1;
            // Transition phases
            if (_phase == 'Inalar') {
              _phase = 'Segurar';
            } else if (_phase == 'Segurar') {
              _phase = 'Exalar';
            } else {
              _phase = 'Inalar';
              _cycleCount++;
            }
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double _getScale() {
    if (_phase == 'Inalar') {
      // Grows from 1.0 to 1.4
      return 1.0 + (_secondsCounter - 1) * 0.08 + (_showNumber ? 0.04 : 0.0);
    } else if (_phase == 'Segurar') {
      return 1.4;
    } else {
      // Shrinks from 1.4 to 1.0
      return 1.4 - (_secondsCounter - 1) * 0.08 - (_showNumber ? 0.04 : 0.0);
    }
  }

  String _getInstructionText() {
    if (_phase == 'Inalar') {
      return 'Inspire lentamente pelo nariz...';
    } else if (_phase == 'Segurar') {
      return 'Segure o ar nos pulmões...';
    } else {
      return 'Expire devagar pela boca...';
    }
  }

  Color _getPhaseColor(ThemeData theme) {
    if (_phase == 'Inalar') {
      return theme.colorScheme.primary;
    } else if (_phase == 'Segurar') {
      return Colors.orange;
    } else {
      return theme.colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phaseColor = _getPhaseColor(theme);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              theme.cardColor,
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.air, color: phaseColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Respiração Consciente (Ciclo $_cycleCount)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(height: 16),
            const SizedBox(height: 12),
            // Breathing Avatar & Count Circle
            Center(
              child: AnimatedScale(
                scale: _getScale(),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: phaseColor.withValues(alpha: 0.25),
                        blurRadius: 15,
                        spreadRadius: 3,
                      )
                    ],
                  ),
                  child: Center(
                    child: _showNumber
                        ? CircleAvatar(
                            radius: 45,
                            backgroundColor: phaseColor,
                            child: Text(
                              '$_secondsCounter',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const GaiaAvatar(radius: 45),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Text Instruction
            Text(
              _getInstructionText(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: phaseColor,
              ),
            ),
            const SizedBox(height: 8),
            // Small hint
            Text(
              'Tente relaxar os ombros e focar apenas no ar.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
