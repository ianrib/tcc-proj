import 'dart:async';
import 'dart:math';
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

  final _random = Random();
  late int _targetCycles;
  late int _pauseDuration;
  late int _expirationDuration;
  int _currentTick = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _targetCycles = 4 + _random.nextInt(5); // 4 a 8 vezes
    _randomizeDurations();
    _startExercise();
  }

  void _randomizeDurations() {
    _pauseDuration = 2 + _random.nextInt(6); // 2-7 segundos
    _expirationDuration = 6 + _random.nextInt(2); // 6-7 segundos
  }

  void _startExercise() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;
      setState(() {
        _currentTick++;
        _showNumber = _currentTick % 2 != 0;
        _secondsCounter = ((_currentTick - 1) ~/ 2) + 1;

        int currentPhaseDuration = 4;
        if (_phase == 'Segurar') {
          currentPhaseDuration = _pauseDuration;
        } else if (_phase == 'Exalar') {
          currentPhaseDuration = _expirationDuration;
        }

        if (_currentTick >= currentPhaseDuration * 2) {
          _currentTick = 0;
          _secondsCounter = 1;
          _showNumber = false;

          if (_phase == 'Inalar') {
            _phase = 'Segurar';
          } else if (_phase == 'Segurar') {
            _phase = 'Exalar';
          } else {
            _phase = 'Inalar';
            _cycleCount++;
            if (_cycleCount > _targetCycles) {
              _completed = true;
              _timer?.cancel();
            } else {
              _randomizeDurations();
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
    if (_completed) return 1.0;
    if (_phase == 'Inalar') {
      double progress = _currentTick / 8.0;
      if (progress > 1.0) progress = 1.0;
      return 1.0 + progress * 0.4;
    } else if (_phase == 'Segurar') {
      return 1.4;
    } else {
      double progress = _currentTick / (_expirationDuration * 2.0);
      if (progress > 1.0) progress = 1.0;
      return 1.4 - progress * 0.4;
    }
  }

  String _getInstructionText() {
    if (_phase == 'Inalar') {
      return 'Inspire lentamente pelo nariz (4s)';
    } else if (_phase == 'Segurar') {
      return 'Segure o ar nos pulmões (${_pauseDuration}s)';
    } else {
      return 'Expire devagar pela boca (${_expirationDuration}s)';
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

  Widget _buildExerciseContent(ThemeData theme, Color phaseColor) {
    return Column(
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
                  'Respiração Consciente (Ciclo $_cycleCount de $_targetCycles)',
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
        // Small hint showing rhythm info
        Text(
          'Ritmo do ciclo: Inspiração 4s | Pausa ${_pauseDuration}s | Expiração ${_expirationDuration}s',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCompletedContent(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Exercício Concluído',
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
        const SizedBox(height: 16),
        const Center(
          child: GaiaAvatar(radius: 45),
        ),
        const SizedBox(height: 24),
        Text(
          'Muito bem!',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Você completou as $_targetCycles repetições de respiração consciente e ajudou a acalmar seu corpo.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.onClose,
            child: const Text('Concluir'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
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
        child: _completed ? _buildCompletedContent(theme) : _buildExerciseContent(theme, phaseColor),
      ),
    );
  }
}
