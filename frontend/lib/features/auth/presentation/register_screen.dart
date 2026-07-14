import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gaia/core/providers/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _cleanErrorMessage(Object e) {
    final raw = e.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.replaceFirst('Exception: ', '');
    }
    return raw;
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnack('Preencha todos os campos.');
      return;
    }
    if (password != confirm) {
      _showSnack('As senhas não coincidem.');
      return;
    }
    if (password.length < 6) {
      _showSnack('A senha deve ter pelo menos 6 caracteres.');
      return;
    }
    if (!_acceptedTerms) {
      _showSnack('Aceite os termos de uso antes de continuar.');
      return;
    }

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signUp(email, password);
      router.go('/chat');
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erro: ${_cleanErrorMessage(e)}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(minHeight: size.height - 60),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 20),

                // ── Card principal ─────────────────────────────────────
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Criar Conta',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Preencha os dados abaixo para se cadastrar',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // E-mail
                        const _FieldLabel('E-mail:'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'Digite seu e-mail',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Senha
                        const _FieldLabel('Senha:'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Mínimo 6 caracteres',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: theme.colorScheme.secondary,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Confirmar Senha
                        const _FieldLabel('Confirmar senha:'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            hintText: 'Repita a senha',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: theme.colorScheme.secondary,
                              ),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Checkbox Termos LGPD
                        Row(
                          children: [
                            Checkbox(
                              value: _acceptedTerms,
                              activeColor: theme.colorScheme.secondary,
                              onChanged: (val) => setState(
                                  () => _acceptedTerms = val ?? false),
                            ),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: 'Li e aceito os ',
                                  style: theme.textTheme.bodySmall,
                                  children: [
                                    TextSpan(
                                      text: 'Termos',
                                      style: TextStyle(
                                        color: theme.colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const TextSpan(text: ' e a '),
                                    TextSpan(
                                      text: 'Política de Privacidade.',
                                      style: TextStyle(
                                        color: theme.colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Botão Cadastrar
                        ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Criar Conta',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),

                        // Link → Já tenho conta
                        Center(
                          child: GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Text.rich(
                              TextSpan(
                                text: 'Já possuo uma conta. ',
                                style: theme.textTheme.bodySmall,
                                children: [
                                  TextSpan(
                                    text: 'Entrar',
                                    style: TextStyle(
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget auxiliar para labels dos campos
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
