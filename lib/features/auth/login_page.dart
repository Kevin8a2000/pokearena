import 'package:flutter/material.dart';

import 'auth_provider.dart';

/// Pantalla de acceso: iniciar sesión o crear cuenta de entrenador.
/// Al entrar, el AuthGate de main.dart muestra la app automáticamente.
class LoginPage extends StatefulWidget {
  final AuthProvider auth;
  const LoginPage({super.key, required this.auth});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _registerMode = false;
  bool _loading = false;
  bool _showPass = false;
  final _user = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (_registerMode) {
        await widget.auth.register(_user.text, _pass.text);
      } else {
        await widget.auth.login(_user.text, _pass.text);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/icons/logo_original.png',
                    width: 220,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.catching_pokemon,
                        size: 48,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'PokéArena',
                  style:
                      TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const Text(
                  'Cada entrenador inicia sesión y guarda su propio equipo.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: false, label: Text('Entrar')),
                    ButtonSegment(
                        value: true, label: Text('Crear cuenta')),
                  ],
                  selected: {_registerMode},
                  onSelectionChanged: (s) => setState(() {
                    _registerMode = s.first;
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _user,
                  textInputAction: TextInputAction.next,
                  maxLength: 16,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    hintText: 'Ej: ash_ketchum',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: !_showPass,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Clave',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip:
                          _showPass ? 'Ocultar' : 'Mostrar',
                      icon: Icon(_showPass
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(
                          () => _showPass = !_showPass),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: widget.auth,
                  builder: (context, _) {
                    final err = widget.auth.error;
                    if (err == null) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        err,
                        style: TextStyle(
                            color: scheme.onErrorContainer),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : Icon(_registerMode
                            ? Icons.person_add
                            : Icons.login),
                    label: Text(_registerMode
                        ? 'Crear cuenta y entrar'
                        : 'Entrar'),
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
