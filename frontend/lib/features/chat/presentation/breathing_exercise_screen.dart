import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/gaia_avatar.dart';

class BreathingExerciseScreen extends StatefulWidget {
  const BreathingExerciseScreen({super.key});

  @override
  State<BreathingExerciseScreen> createState() => _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen> {
  Timer? _timer;
  String _phase = 'Prepare-se'; // 'Prepare-se', 'Inalar', 'Segurar', 'Exalar', 'Comemoração'
  int _secondsCounter = 3;
  int _cycleCount = 1;
  late int _targetCycles;
  late int _pauseDuration;
  late int _expirationDuration;
  int _currentTick = 0;

  @override
  void initState() {
    super.initState();
    _targetCycles = 4; // Focado em 4 ciclos completos para uma experiência fluida no TCC
    _randomizeDurations();
    _startTimer();
  }

  void _randomizeDurations() {
    _pauseDuration = 4; // Ritmo padrão recomendado (4-4-4 ou 4-4-6)
    _expirationDuration = 6;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;
      setState(() {
        if (_phase == 'Prepare-se') {
          _currentTick++;
          if (_currentTick >= 6) { // 3 segundos (6 ticks)
            _phase = 'Inalar';
            _currentTick = 0;
            _secondsCounter = 1;
          } else {
            _secondsCounter = 3 - (_currentTick ~/ 2);
          }
        } else if (_phase == 'Comemoração') {
          // Timer cancelado antes de entrar em comemoração
        } else {
          _currentTick++;
          int currentPhaseDuration = 4;
          if (_phase == 'Segurar') {
            currentPhaseDuration = _pauseDuration;
          } else if (_phase == 'Exalar') {
            currentPhaseDuration = _expirationDuration;
          }

          _secondsCounter = (_currentTick ~/ 2) + 1;

          if (_currentTick >= currentPhaseDuration * 2) {
            _currentTick = 0;
            _secondsCounter = 1;

            if (_phase == 'Inalar') {
              _phase = 'Segurar';
            } else if (_phase == 'Segurar') {
              _phase = 'Exalar';
            } else {
              if (_cycleCount >= _targetCycles) {
                _phase = 'Comemoração';
                _timer?.cancel();
                _timer = null;
                // Exibe comemoração por 2.5 segundos e fecha automaticamente
                Timer(const Duration(milliseconds: 2500), () {
                  if (mounted) {
                    context.go('/chat');
                  }
                });
              } else {
                _phase = 'Inalar';
                _cycleCount++;
                _randomizeDurations();
              }
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
    if (_phase == 'Prepare-se' || _phase == 'Comemoração') return 1.0;
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

  String _getInstructionTitle() {
    switch (_phase) {
      case 'Prepare-se':
        return 'Prepare-se';
      case 'Inalar':
        return 'Inalar';
      case 'Segurar':
        return 'Segurar';
      case 'Exalar':
        return 'Exalar';
      case 'Comemoração':
        return 'Muito Bem!';
      default:
        return '';
    }
  }

  String _getInstructionSubtitle() {
    switch (_phase) {
      case 'Prepare-se':
        return 'Encontre uma posição confortável';
      case 'Inalar':
        return 'Inspire lentamente pelo nariz';
      case 'Segurar':
        return 'Mantenha o ar nos pulmões';
      case 'Exalar':
        return 'Solte o ar devagar pela boca';
      case 'Comemoração':
        return 'Você concluiu o exercício com sucesso';
      default:
        return '';
    }
  }

  Color _getPhaseColor(ThemeData theme) {
    switch (_phase) {
      case 'Prepare-se':
        return theme.colorScheme.primary;
      case 'Inalar':
        return theme.colorScheme.primary;
      case 'Segurar':
        return Colors.orange;
      case 'Exalar':
        return theme.colorScheme.secondary;
      case 'Comemoração':
        return Colors.teal;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phaseColor = _getPhaseColor(theme);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.scaffoldBackgroundColor,
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Barra superior com botão voltar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface),
                      onPressed: () => context.go('/chat'),
                    ),
                    Text(
                      'Respiração Guiada',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 48), // Espaçador para centralizar título
                  ],
                ),
              ),
              const Spacer(),

              // Círculo Central do Exercício
              Center(
                child: AnimatedScale(
                  scale: _getScale(),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: phaseColor.withValues(alpha: 0.25),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ],
                      border: Border.all(
                        color: phaseColor.withValues(alpha: 0.4),
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: _buildCenterWidget(phaseColor),
                    ),
                  ),
                ),
              ),
              
              const Spacer(),

              // Instruções de texto e contagem de ciclo
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Text(
                      _getInstructionTitle(),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: phaseColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getInstructionSubtitle(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Indicador de ciclo
                    if (_phase != 'Prepare-se' && _phase != 'Comemoração') ...[
                      Text(
                        'Ciclo $_cycleCount de $_targetCycles',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_targetCycles, (index) {
                          final isActive = index + 1 == _cycleCount;
                          final isCompleted = index + 1 < _cycleCount;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted
                                  ? theme.colorScheme.primary
                                  : isActive
                                      ? phaseColor
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterWidget(Color phaseColor) {
    if (_phase == 'Prepare-se') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const GaiaAvatar(radius: 50),
          const SizedBox(height: 8),
          Text(
            '$_secondsCounter',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: phaseColor,
            ),
          ),
        ],
      );
    } else if (_phase == 'Comemoração') {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GaiaAvatar(radius: 50),
          SizedBox(height: 8),
          Icon(Icons.check_circle_rounded, color: Colors.teal, size: 28),
        ],
      );
    } else {
      // Nas contagens de respiração ativa, apenas o número de segundos de forma estática (sem oscilar com avatar)
      return Text(
        '$_secondsCounter',
        style: TextStyle(
          fontSize: 64,
          fontWeight: FontWeight.bold,
          color: phaseColor,
        ),
      );
    }
  }
}
