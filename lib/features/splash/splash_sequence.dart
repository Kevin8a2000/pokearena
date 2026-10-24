import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/pokemon.dart';
import 'onboarding_page.dart';

/// Intro con secuencia de pantallas propias + carga real:
/// mientras se muestran las 3 imágenes se precargan los artworks de la
/// Pokédex (el tiempo depende de la red). Al terminar aparece JUGAR.
class SplashSequence extends StatefulWidget {
  final Widget child;
  final int warmupCount;
  final bool warmupImages;
  const SplashSequence({
    super.key,
    required this.child,
    this.warmupCount = 60,
    this.warmupImages = true,
  });

  static const _slides = [
    (
      asset: 'assets/images/splash/splash_1.jpg',
      caption: 'Vive batallas épicas',
    ),
    (
      asset: 'assets/images/splash/splash_2.png',
      caption: 'Arma tu equipo',
    ),
    (
      asset: 'assets/images/splash/splash_3.jpeg',
      caption: '¡Hazte con todos!',
    ),
  ];

  @override
  State<SplashSequence> createState() => _SplashSequenceState();
}

class _SplashSequenceState extends State<SplashSequence> {
  final _ctrl = PageController();
  int _page = 0;
  int _done = 0;
  bool _ready = false;
  bool _needsOnboarding = false;
  bool _onboardingDone = false;
  bool _entered = false;
  Timer? _auto;

  int get _total => widget.warmupCount;

  @override
  void initState() {
    super.initState();
    _auto = Timer.periodic(
      const Duration(milliseconds: 1800),
      (_) => _nextSlide(),
    );
    _boot();
  }

  void _nextSlide() {
    if (!mounted || _ready || !_ctrl.hasClients) return;
    final next = _page + 1;
    if (next >= SplashSequence._slides.length) return;
    _ctrl.animateToPage(
      next,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _precacheOne(int id) async {
    try {
      await precacheImage(NetworkImage(officialArtwork(id)), context);
    } catch (_) {}
  }

  Future<void> _boot() async {
    final stopwatch = Stopwatch()..start();
    try {
      final prefs = await SharedPreferences.getInstance();
      _needsOnboarding =
          !(prefs.getBool('pokearena_onboarding_done') ?? false);
    } catch (_) {}
    // Precarga real en tandas de 6 (no satura la red).
    if (widget.warmupImages) {
      for (var start = 1;
          start <= _total && mounted;
          start += 6) {
        final end = (start + 5).clamp(1, _total);
        await Future.wait(
            [for (var id = start; id <= end; id++) _precacheOne(id)]);
        if (!mounted) return;
        setState(() => _done = end);
      }
    } else {
      if (mounted) setState(() => _done = _total);
    }
    // Mínimo en pantalla para que la secuencia se aprecie.
    final left =
        const Duration(milliseconds: 3500) - stopwatch.elapsed;
    if (left > Duration.zero) await Future.delayed(left);
    if (!mounted) return;
    _auto?.cancel();
    setState(() => _ready = true);
  }

  void _enter() {
    if (_entered || !mounted) return;
    setState(() => _entered = true);
  }

  @override
  void dispose() {
    _auto?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_entered) {
      if (_needsOnboarding && !_onboardingDone) {
        return OnboardingPage(
          onFinish: () => setState(() => _onboardingDone = true),
        );
      }
      return widget.child;
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (_ctrl.hasClients) {
            _ctrl.animateToPage(
              SplashSequence._slides.length - 1,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );
          }
        },
        child: Stack(
          children: [
            PageView.builder(
            controller: _ctrl,
            itemCount: SplashSequence._slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final s = SplashSequence._slides[i];
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    s.asset,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, st) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF1B2A4A),
                            Color(0xFF0D1526),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 130,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          s.caption,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0;
                        i < SplashSequence._slides.length;
                        i++)
                      Container(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 4),
                        width: _page == i ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _page == i
                              ? const Color(0xFFFFCB05)
                              : Colors.white54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_ready) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.2),
                      valueColor:
                          const AlwaysStoppedAnimation(
                              Color(0xFFFFCB05)),
                      value: _total == 0 ? 0 : _done / _total,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cargando Pokédex $_done/$_total · toca para adelantar',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFCB05),
                        foregroundColor: const Color(0xFF0D1526),
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                      ),
                      onPressed: () {
                        // La música ya arrancó sola al salir el menú.
                        _enter();
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text(
                        'JUGAR',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}
