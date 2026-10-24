import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings/settings_provider.dart';
import 'battle_calculator.dart';
import 'battle_hints.dart';
import 'battle_provider.dart';
import 'gba/gba_touch_menu.dart';

/// Abre el tutorial a pantalla completa y, al cerrarlo (terminado o saltado),
/// lo marca como visto para no volver a mostrarlo solo.
Future<void> showBattleTutorial(BuildContext context) async {
  SettingsProvider? settings;
  try {
    settings = context.read<SettingsProvider>();
  } catch (_) {}
  await Navigator.of(context).push<void>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => const BattleTutorial()),
  );
  settings?.markBattleTutorialSeen();
}

/// Empieza la batalla; la primera vez (en cualquier modo) enseña antes cómo
/// se juega.
Future<void> startBattleWithTutorial(BuildContext context, BattleProvider b) async {
  var seen = true;
  try {
    seen = context.read<SettingsProvider>().battleTutorialSeen;
  } catch (_) {}
  if (!seen) {
    await showBattleTutorial(context);
    if (!context.mounted) return;
  }
  await b.startBattle();
}

const _bg = Color(0xFF101014);

/// Tutorial de batalla: 4 láminas con ejemplos reales de los botones y
/// tarjetas que verá el jugador. Los 4 botones de acción (LUCHAR/MOCHILA/
/// POKÉMON/HUIR) ya no van aquí: se explican con foco de luz sobre los
/// botones reales la primera vez que arranca el combate (ver
/// `gba/gba_action_spotlight.dart`).
class BattleTutorial extends StatefulWidget {
  const BattleTutorial({super.key});

  @override
  State<BattleTutorial> createState() => _BattleTutorialState();
}

class _BattleTutorialState extends State<BattleTutorial> {
  final _controller = PageController();
  int _page = 0;

  static const _count = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _count - 1) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _count - 1;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Saltar', style: TextStyle(color: Colors.white70)),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _Slide(icon: Icons.sports_mma, title: 'Así se combate', child: _HowItWorks()),
                  _Slide(icon: Icons.bolt, title: 'Un ataque, dato por dato', child: _MoveAnatomy()),
                  _Slide(icon: Icons.star, title: 'Eficacia y ★ recomendado', child: _Effectiveness()),
                  _Slide(icon: Icons.medication, title: 'Poción, cambio y Mov. Z', child: _Extras()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _count; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _page ? 18 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page ? Colors.amber : Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  FilledButton(onPressed: _next, child: Text(last ? '¡Entendido!' : 'Siguiente')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marco de una lámina: icono + título y contenido desplazable y centrado.
class _Slide extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Slide({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.amber, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila "icono + texto" de explicación.
class _Point extends StatelessWidget {
  final Widget leading;
  final String title;
  final String text;
  const _Point({required this.leading, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 44, child: Center(child: leading)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _Point(
          leading: Icon(Icons.repeat, color: Colors.lightBlueAccent, size: 30),
          title: 'Por turnos',
          text: 'Cada turno eliges UNA acción: atacar, curarte, cambiar de Pokémon o huir.',
        ),
        _Point(
          leading: Icon(Icons.speed, color: Colors.amber, size: 30),
          title: 'El más veloz pega primero',
          text: 'Después responde el rival. Observa la barra de PS de cada uno.',
        ),
        _Point(
          leading: Icon(Icons.favorite, color: Colors.redAccent, size: 30),
          title: 'Gana quien deje sin PS al rival',
          text: 'Si tu Pokémon cae, entra el siguiente de tu equipo. Si caen todos, pierdes.',
        ),
        _Point(
          leading: Icon(Icons.touch_app, color: Colors.greenAccent, size: 30),
          title: 'Todo se toca',
          text: 'Los botones están sobre el juego, un poco transparentes. Si prefieres cruceta y A/B, cambia en el botón del mando de arriba.',
        ),
      ],
    );
  }
}

class _MoveAnatomy extends StatelessWidget {
  const _MoveAnatomy();

  @override
  Widget build(BuildContext context) {
    const sample = BattleMove(name: 'Lanzallamas', type: 'fire', power: 90, maxPp: 15, accuracy: 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SizedBox(
            width: 190,
            child: GbaMoveCard(
              move: sample,
              ppLeft: 4,
              effectiveness: 2,
              recommended: true,
              enabled: true,
              onTap: () {},
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _Point(
          leading: Icon(Icons.label, color: Colors.orangeAccent, size: 26),
          title: 'Nombre y tipo',
          text: 'El círculo de color es el tipo del ataque (fuego, agua, planta…).',
        ),
        const _Point(
          leading: Icon(Icons.fitness_center, color: Colors.redAccent, size: 26),
          title: 'Poder',
          text: 'Cuánto daño hace de base. Más poder, más golpe.',
        ),
        const _Point(
          leading: Icon(Icons.gps_fixed, color: Colors.lightBlueAccent, size: 26),
          title: 'Precisión',
          text: 'Probabilidad de acertar. Con 90 % falla 1 de cada 10 veces.',
        ),
        const _Point(
          leading: Icon(Icons.battery_5_bar, color: Colors.lightGreenAccent, size: 26),
          title: 'PP',
          text: 'Usos que le quedan. La barra se pone roja cuando quedan pocos; sin PP no se puede usar.',
        ),
      ],
    );
  }
}

class _Effectiveness extends StatelessWidget {
  const _Effectiveness();

  Widget _badge(double eff) {
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: effectivenessColor(effectivenessTier(eff)), borderRadius: BorderRadius.circular(8)),
      child: Text(
        eff == 0 ? '×0' : eff == 0.5 ? '×½' : '×${eff.toInt()}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Point(leading: _badge(2), title: effectivenessLabel(2), text: 'El tipo del ataque es fuerte contra el rival: hace el doble de daño.'),
        _Point(leading: _badge(1), title: effectivenessLabel(1), text: 'Daño normal.'),
        _Point(leading: _badge(0.5), title: effectivenessLabel(0.5), text: 'El rival resiste el ataque: hace la mitad.'),
        _Point(leading: _badge(0), title: effectivenessLabel(0), text: 'El rival es inmune: no hace nada.'),
        const _Point(
          leading: Icon(Icons.star, color: Colors.amber, size: 30),
          title: 'La estrella marca el mejor ataque',
          text: 'Combina poder, eficacia, precisión y que sea del mismo tipo que tu Pokémon (+50 %). Si dudas, toca el de la ★.',
        ),
        const _Point(
          leading: Icon(Icons.flash_on, color: Colors.deepOrangeAccent, size: 30),
          title: 'Golpe crítico',
          text: 'De vez en cuando un golpe sale con más fuerza: ¡sorpresa!',
        ),
      ],
    );
  }
}

class _Extras extends StatelessWidget {
  const _Extras();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _Point(
          leading: Icon(Icons.medication, color: Colors.greenAccent, size: 30),
          title: 'Poción',
          text: 'Tienes pocas por combate. Cura 40 % de los PS del luchador activo y pierdes el turno.',
        ),
        _Point(
          leading: Icon(Icons.catching_pokemon, color: Colors.lightGreenAccent, size: 30),
          title: 'Cambiar de Pokémon',
          text: 'Elige uno de tu equipo con la tarjeta (barra de PS). Los debilitados no se pueden elegir.',
        ),
        _Point(
          leading: Icon(Icons.auto_awesome, color: Colors.amber, size: 30),
          title: 'Mov. Z',
          text: 'Cada golpe que das carga una barra. Al llegar al 100 % aparece una tarjeta dorada con un ataque devastador.',
        ),
        _Point(
          leading: Icon(Icons.help_outline, color: Colors.white70, size: 30),
          title: '¿Dudas?',
          text: 'Toca el botón ? de arriba durante el combate para ver este tutorial otra vez.',
        ),
      ],
    );
  }
}
