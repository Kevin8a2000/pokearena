import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding de primera vez: 3 tarjetas deslizables + Empezar.
class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingPage({super.key, required this.onFinish});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _ctrl = PageController();
  int _page = 0;

  static const _slides = [
    (
      icon: Icons.catching_pokemon,
      title: 'Explora la Pokédex',
      text: 'Más de 1000 Pokémon con tipos, stats, gritos y evoluciones.',
    ),
    (
      icon: Icons.groups,
      title: 'Arma tu equipo',
      text: 'Elige hasta 6 luchadores y revisa tu cobertura de tipos.',
    ),
    (
      icon: Icons.monetization_on,
      title: 'Pelea y desbloquea',
      text: 'Gana batallas, junta monedas y desbloquea nuevos avatares.',
    ),
  ];

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pokearena_onboarding_done', true);
    } catch (_) {}
    widget.onFinish();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1526),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFCB05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s.icon,
                              size: 56,
                              color: const Color(0xFF0D1526)),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _page == i ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _page == i
                          ? const Color(0xFFFFCB05)
                          : Colors.white30,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCB05),
                    foregroundColor: const Color(0xFF0D1526),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: last
                      ? _finish
                      : () => _ctrl.nextPage(
                            duration:
                                const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                  child: Text(
                    last ? 'Empezar' : 'Siguiente',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
