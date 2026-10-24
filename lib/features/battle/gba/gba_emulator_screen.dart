import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/sound_service.dart';
import '../../settings/settings_provider.dart';
import '../battle_provider.dart';
import '../battle_sound.dart';
import '../battle_tutorial.dart';
import 'gba_action_spotlight.dart';
import 'gba_controls.dart';
import 'gba_touch_menu.dart';
import 'gba_viewport.dart';

/// Pantalla consola GBA: viewport 3:2 arriba + carcasa con controles abajo.
/// El D-Pad mueve el cursor, A confirma, B retrocede, L/R cambian de
/// luchador, START abre/cierra el menú y SELECT silencia/activa el sonido.
class GbaEmulatorScreen extends StatefulWidget {
  const GbaEmulatorScreen({super.key});

  @override
  State<GbaEmulatorScreen> createState() => _GbaEmulatorScreenState();
}

class _GbaEmulatorScreenState extends State<GbaEmulatorScreen> {
  int _menuCursor = 0;
  int _mode = 0; // 0 acciones, 1 ataques, 2 mochila, 3 pokémon
  int _sub = 0;
  bool _menuOpen = true;
  bool _soundOn = true;

  /// Esquina superior-izquierda del menú flotante (coords de pantalla).
  /// null = posición por defecto (abajo-derecha de la zona de pelea).
  Offset? _menuPos;

  /// Llaves de los 4 botones reales (LUCHAR/MOCHILA/POKÉMON/HUIR), del panel
  /// de submenú (ataques/mochila/equipo, uno a la vez), de la placa HP del
  /// jugador y de los interruptores de sonido/ayuda, para que el tutorial
  /// de foco de luz encuentre la posición exacta de cada uno en pantalla.
  final List<GlobalKey> _actionKeys = List.generate(4, (_) => GlobalKey());
  final GlobalKey _panelKey = GlobalKey();
  final GlobalKey _playerHpKey = GlobalKey();
  final GlobalKey _miniRowKey = GlobalKey();
  bool _spotlightActive = false;
  bool _spotlightChecked = false;

  /// Recorrido completo: cada botón real seguido de la explicación de lo
  /// que abre (sus tarjetas reales, con los datos de este combate).
  late final List<GbaSpotlightStep> _tutorialSteps = [
    GbaSpotlightStep(
      requiredMode: 0,
      target: _playerHpKey,
      icon: Icons.favorite,
      title: 'TUS PS',
      text: 'Aquí ves los PS (puntos de salud) y el nivel de tu Pokémon activo. Si sus PS llegan a 0, se debilita y entra el siguiente de tu equipo.',
    ),
    GbaSpotlightStep(
      requiredMode: 0,
      target: _miniRowKey,
      icon: Icons.volume_up,
      title: 'SONIDO Y AYUDA',
      text: 'Aquí silencias los efectos de sonido del combate y vuelves a ver este tutorial cuando quieras.',
    ),
    GbaSpotlightStep(
      requiredMode: 0,
      target: _actionKeys[0],
      icon: gbaActions[0].icon,
      title: gbaActions[0].title,
      text: 'Abre tus ataques: es la acción principal del turno. Tipo de uso: ofensivo. Coste: ninguno extra, solo gastas el turno en atacar.',
    ),
    GbaSpotlightStep(
      requiredMode: 1,
      target: _panelKey,
      icon: Icons.bolt,
      title: 'TUS ATAQUES',
      text: 'Cada tarjeta es un ataque: tipo, poder, precisión y los PP que le quedan. La franja de abajo dice qué tan efectivo es contra el rival, y la ★ marca el recomendado.',
    ),
    GbaSpotlightStep(
      requiredMode: 0,
      target: _actionKeys[1],
      icon: gbaActions[1].icon,
      title: gbaActions[1].title,
      text: 'Usa una poción de tu mochila. Tipo de uso: curación/defensivo. Coste: cede el turno y gasta 1 poción (tienes pocas por combate).',
    ),
    GbaSpotlightStep(
      requiredMode: 2,
      target: _panelKey,
      icon: Icons.medication,
      title: 'TU POCIÓN',
      text: 'Cura el 40 % de los PS del Pokémon que está peleando ahora mismo. Tienes un número limitado por combate y usarla cede el turno.',
    ),
    GbaSpotlightStep(
      requiredMode: 0,
      target: _actionKeys[2],
      icon: gbaActions[2].icon,
      title: gbaActions[2].title,
      text: 'Cambia al Pokémon activo por otro de tu equipo. Tipo de uso: táctico, útil si el rival te gana en tipo. Coste: cede el turno.',
    ),
    GbaSpotlightStep(
      requiredMode: 3,
      target: _panelKey,
      icon: Icons.catching_pokemon,
      title: 'TU EQUIPO',
      text: 'Toca una tarjeta para que pelee en su lugar. La barra es su PS; no puedes elegir al que ya está peleando ni a uno debilitado.',
    ),
    GbaSpotlightStep(
      requiredMode: 0,
      target: _actionKeys[3],
      icon: gbaActions[3].icon,
      title: gbaActions[3].title,
      text: 'Escapa del combate. Tipo de uso: salida de emergencia. Coste: sales sin recompensa; pide confirmación antes de huir.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _soundOn = SoundService.enabled;
  }

  /// La primera vez que el combate empieza (y nunca antes), enciende el
  /// recorrido con foco de luz sobre los 4 botones reales.
  void _maybeStartSpotlight(BattleProvider b) {
    if (_spotlightChecked || b.entering || !_menuOpen || _mode != 0) return;
    _spotlightChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      var seen = true;
      try {
        seen = context.read<SettingsProvider>().actionsTutorialSeen;
      } catch (_) {}
      if (!seen) setState(() => _spotlightActive = true);
    });
  }

  /// Termina el recorrido (al acabar el último paso o al Saltar) y deja el
  /// menú en reposo, sin importar en qué submenú lo haya dejado el tutorial.
  void _endSpotlight() {
    setState(() {
      _spotlightActive = false;
      _mode = 0;
    });
    try {
      context.read<SettingsProvider>().markActionsTutorialSeen();
    } catch (_) {}
  }

  int get _moveCount {
    final b = context.read<BattleProvider>();
    return b.playerMoves.length + (b.playerCharge >= 100 ? 1 : 0);
  }

  bool get _canInput {
    final b = context.read<BattleProvider>();
    return !b.busy &&
        !b.botThinking &&
        !b.entering &&
        b.winner == null &&
        b.phase == BattlePhase.fighting;
  }

  /// Navegación en cuadrícula de 2 columnas (panel moderno).
  /// Modo 1 = ataques, 2 = mochila, 3 = equipo.
  void _shift(int d) {
    if (!_canInput || !_menuOpen) return;
    setState(() {
      final n = _panelCount();
      if (n <= 0) return;
      if (_mode == 0) {
        _menuCursor = (_menuCursor + d) % 4;
      } else {
        _sub = (_sub + d) % n;
      }
    });
  }

  void _up() => _shift(-2);

  void _down() => _shift(2);

  void _left() => _shift(-1);

  void _right() => _shift(1);

  /// Entradas del submenú actual (para navegar).
  int _panelCount() {
    final b = context.read<BattleProvider>();
    return switch (_mode) {
      1 => _moveCount,
      2 => 1, // Poción
      3 => b.playerTeam.length,
      _ => 4,
    };
  }

  void _pressA() {
    final b = context.read<BattleProvider>();
    if (b.entering && b.introRich) {
      b.skipIntro(); // A salta la entrada con entrenadores
      return;
    }
    if (!_canInput) return;
    if (!_menuOpen) {
      setState(() => _menuOpen = true);
      return;
    }
    if (_mode == 1) {
      final moves = b.playerMoves;
      if (_sub < moves.length) {
        final m = moves[_sub];
        BattleSound.playSelect();
        b.playerAttack(m);
      } else {
        b.playerUltimate();
      }
      return;
    }
    if (_mode == 2) {
      BattleSound.playSelect();
      b.usePotion();
      return;
    }
    if (_mode == 3) {
      BattleSound.playSelect();
      b.switchPlayerFighter(_sub);
      return;
    }
    switch (_menuCursor) {
      case 0: // LUCHAR
        setState(() {
          _mode = 1;
          _sub = 0;
        });
      case 1: // MOCHILA
        setState(() {
          _mode = 2;
          _sub = 0;
        });
      case 2: // POKÉMON
        setState(() {
          _mode = 3;
          _sub = 0;
        });
      case 3: // HUIR
        b.backToSelect();
    }
  }

  void _pressB() {
    if (_mode != 0) {
      setState(() => _mode = 0);
    }
  }

  void _cycleFighter(BattleProvider b, int dir) {
    final n = b.playerTeam.length;
    if (n < 2 || !_canInput) return;
    for (var k = 1; k <= n; k++) {
      final i = (b.playerActive + dir * k) % n;
      if (b.playerTeamHp[i] > 0 && i != b.playerActive) {
        b.switchPlayerFighter(i);
        return;
      }
    }
  }

  void _pressStart() => setState(() {
        _menuOpen = !_menuOpen;
        _mode = 0;
      });

  void _pressSelect() {
    setState(() => _soundOn = !_soundOn);
    BattleSound.toggle(_soundOn);
  }

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    _maybeStartSpotlight(context.watch<BattleProvider>());
    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return LayoutBuilder(
              builder: (context, cons) {
                final area = cons.biggest;
                final landscape = orientation == Orientation.landscape;
                final layout = landscape ? GbaLandscapeLayout.compute(area) : null;
                final content = landscape ? _landscapeBody(context, layout!) : _portraitBody();
                // Capa flotante: el menú se arrastra por TODA la pantalla
                // (pelea + controles), las placas HP quedan fijas.
                return Stack(
                  key: _stackKey,
                  // Siempre ocupa toda el área: sin esto, al ocultarse el menú
                  // (su capa pasa a un SizedBox.shrink) el Stack se encogía a
                  // 0x0 y desaparecía toda la pantalla.
                  fit: StackFit.expand,
                  children: [
                    content,
                    _menuOverlay(context, orientation, area, layout),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Anchura aproximada del panel del menú (216 + margen) y alto máximo.
  static const double _menuW = 228;
  static const double _menuMaxH = 260;

  /// Menú flotante arrastrable. Solo se muestra cuando toca elegir.
  Widget _menuOverlay(
    BuildContext context,
    Orientation orientation,
    Size area,
    GbaLandscapeLayout? layout,
  ) {
    final b = context.watch<BattleProvider>();
    final show = _menuOpen &&
        !b.busy &&
        !b.botThinking &&
        b.winner == null &&
        !(b.entering && b.introRich); // sin menú sobre la entrada
    // En horizontal el menú es la barra táctil; este flotante es del vertical.
    if (!show || layout != null) return const SizedBox.shrink();

    final panel = GestureDetector(
      onPanStart: (_) => _anchorMenu(),
      onPanUpdate: (d) => setState(() {
        final cur = _menuPos ?? Offset.zero;
        _menuPos = Offset(
          (cur.dx + d.delta.dx).clamp(0.0, math.max(0.0, area.width - _menuW)),
          (cur.dy + d.delta.dy).clamp(0.0, math.max(0.0, area.height - 120)),
        );
      }),
      child: Column(
        key: _menuKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.drag_handle, size: 14, color: Colors.white70),
          ),
          GbaRetroMenu(
            b: b,
            menuCursor: _menuCursor,
            mode: _mode,
            subCursor: _sub,
            // Toque directo: equivale a mover el cursor y pulsar A.
            onAction: (i) {
              setState(() => _menuCursor = i);
              _pressA();
            },
            onMove: (i) {
              setState(() => _sub = i);
              _pressA();
            },
            onBack: _pressB,
          ),
        ],
      ),
    );

    final base = _menuPos ?? _defaultMenuPos(area);
    final pos = Offset(
      base.dx.clamp(0.0, math.max(0.0, area.width - _menuW)),
      base.dy.clamp(0.0, math.max(0.0, area.height - _menuMaxH)),
    );
    return Positioned(left: pos.dx, top: pos.dy, child: panel);
  }

  /// Convierte la posición anclada en coordenadas absolutas al empezar a
  /// arrastrar (así el arrastre parte de donde está el menú).
  void _anchorMenu() {
    if (_menuPos != null) return;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final menu = _menuKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || menu == null) return;
    setState(() => _menuPos = menu.localToGlobal(Offset.zero, ancestor: stack));
  }

  /// Posición inicial en vertical: abajo-derecha de la zona de pelea.
  Offset _defaultMenuPos(Size size) {
    final vw = size.width - 16;
    final vh = vw * 3 / 4;
    return Offset(size.width - 16 - 220, 24 + vh - 160);
  }

  /// Cuerpo apaisado: la escena ocupa TODA la pantalla y el menú táctil se
  /// dibuja encima, translúcido. La escena se
  /// dibuja a un lienzo de [GbaLandscapeLayout.designH] de alto y del ancho
  /// que pida el aspecto de la pantalla, y se escala (FittedBox) para que todo
  /// (Pokémon, placas, efectos) crezca junto.
  Widget _landscapeBody(BuildContext context, GbaLandscapeLayout l) {
    return Positioned.fill(
      child: Stack(
        children: [
          // Escena a pantalla completa.
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: l.designW,
                height: l.designH,
                child: GbaViewport(
                  menuCursor: _menuCursor,
                  inMoves: _mode == 1,
                  moveCursor: _sub,
                  menuOpen: _menuOpen,
                  overlay: true,
                  // En reposo los 4 botones tapan la derecha del diálogo.
                  dialogueInset: (kActionsWidth + 12) / l.scale,
                  hideDialogue: _mode != 0,
                  playerHpKey: _playerHpKey,
                ),
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _touchBar()),
          // Interruptores pequeños (sonido, tutorial, vista) arriba al centro.
          Positioned(top: 30, left: 0, right: 0, child: Center(child: _miniRow())),
          // Recorrido con foco de luz sobre los 4 botones reales (solo la
          // primera vez, o al reabrirlo a mano desde el botón ? de arriba).
          if (_spotlightActive)
            Positioned.fill(
              child: GbaActionSpotlight(
                steps: _tutorialSteps,
                currentMode: _mode,
                onNeedMode: (m) => setState(() => _mode = m),
                onDone: _endSpotlight,
              ),
            ),
        ],
      ),
    );
  }

  /// Barra inferior translúcida: acciones, ataques, mochila o equipo (se
  /// repinta con el combate).
  Widget _touchBar() {
    return Consumer<BattleProvider>(
      builder: (context, b, _) => GbaTouchBar(
        b: b,
        mode: _mode,
        enabled: _canInput,
        onAction: _touchAction,
        onMove: _touchMove,
        onUltimate: _touchUltimate,
        onPotion: _touchPotion,
        onSwitch: _touchSwitch,
        onBack: _touchBack,
        actionKeys: _actionKeys,
        panelKey: _panelKey,
      ),
    );
  }

  /// Interruptores pequeños: sonido, tutorial y vista.
  Widget _miniRow() {
    return Row(
      key: _miniRowKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        _miniButton(_soundOn ? Icons.volume_up : Icons.volume_off, 'Sonido', _pressSelect),
        const SizedBox(width: 8),
        _miniButton(Icons.help_outline, 'Tutorial', () async {
          await showBattleTutorial(context);
          if (!mounted) return;
          setState(() {
            _mode = 0;
            _spotlightActive = true;
          });
        }),
      ],
    );
  }

  Widget _miniButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white38),
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
  }

  /// Toque en una acción: abre su panel (HUIR pide confirmación).
  void _touchAction(int i) {
    if (!_canInput) return;
    BattleSound.playSelect();
    if (i == 3) {
      _confirmFlee();
      return;
    }
    setState(() {
      _menuCursor = i;
      _mode = i + 1;
      _sub = 0;
    });
  }

  Future<void> _confirmFlee() async {
    final b = context.read<BattleProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Huir del combate?'),
        content: const Text('Saldrás de la batalla sin recompensa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir peleando')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Huir')),
        ],
      ),
    );
    if (ok == true && mounted) b.backToSelect();
  }

  void _touchMove(int i) {
    if (!_canInput) return;
    final b = context.read<BattleProvider>();
    final moves = b.playerMoves;
    if (i < 0 || i >= moves.length || b.playerPpLeft(i) <= 0) return;
    BattleSound.playSelect();
    setState(() => _mode = 0);
    b.playerAttack(moves[i]);
  }

  void _touchUltimate() {
    if (!_canInput) return;
    BattleSound.playSelect();
    setState(() => _mode = 0);
    context.read<BattleProvider>().playerUltimate();
  }

  void _touchPotion() {
    if (!_canInput) return;
    BattleSound.playSelect();
    setState(() => _mode = 0);
    context.read<BattleProvider>().usePotion();
  }

  void _touchSwitch(int i) {
    if (!_canInput) return;
    BattleSound.playSelect();
    setState(() => _mode = 0);
    context.read<BattleProvider>().switchPlayerFighter(i);
  }

  void _touchBack() => setState(() => _mode = 0);


  /// Cuerpo vertical: pantalla grande arriba, controles compactos abajo.
  Widget _portraitBody() {
            // Vertical: pantalla grande arriba, controles compactos abajo.
            return SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  const Text(
                    'GAME BOY ADVANCE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 1. Pantalla del juego (más alta: 4/3 para priorizar
                  // la pelea y que el HP rival nunca se recorte).
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child:
                          _viewportBox(const EdgeInsets.all(0)),
                    ),
                  ),
                  GbaTriggers(
                    onL: () => _cycleFighter(
                        context.read<BattleProvider>(), -1),
                    onR: () => _cycleFighter(
                        context.read<BattleProvider>(), 1),
                  ),
                  // 2. Carcasa con controles (compacta: la pelea manda).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        8, 0, 8, 12),
                    child: _chassis(),
                  ),
                  const Text(
                    'GAME BOY ADVANCE',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          }

  /// Marco negro con bisel que envuelve el viewport 3:2.
  Widget _viewportBox(EdgeInsets margin) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFF333333), width: 4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: GbaViewport(
          menuCursor: _menuCursor,
          inMoves: _mode == 1,
          moveCursor: _sub,
          menuOpen: _menuOpen,
        ),
      ),
    );
  }

  /// Carcasa gris compacta: la pantalla de pelea es la protagonista.
  Widget _chassis({bool compact = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C34),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              if (compact)
                SizedBox(
                  width: 112,
                  height: 112,
                  child: FittedBox(
                    child: GbaDPad(
                      onUp: _up,
                      onDown: _down,
                      onLeft: _left,
                      onRight: _right,
                    ),
                  ),
                )
              else ...[
                SizedBox(
                  width: 118,
                  height: 118,
                  child: FittedBox(
                    child: GbaDPad(
                      onUp: _up,
                      onDown: _down,
                      onLeft: _left,
                      onRight: _right,
                    ),
                  ),
                ),
                SizedBox(
                  width: 132,
                  child: FittedBox(
                    child:
                        GbaABButtons(onA: _pressA, onB: _pressB),
                  ),
                ),
              ],
              if (compact)
                GbaABButtons(onA: _pressA, onB: _pressB),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GbaOptionButton(
                  label: _soundOn
                      ? 'SELECT · SONIDO'
                      : 'SELECT · MUDO',
                  onTap: _pressSelect),
              const SizedBox(width: 24),
              GbaOptionButton(
                  label: 'START · MENÚ',
                  onTap: _pressStart),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reparto del espacio en horizontal: la escena ocupa toda la pantalla y se
/// dibuja en un lienzo de [baseH] de alto y del ancho que pida el aspecto
/// (así los Pokémon y placas, anclados a los bordes, se separan en pantallas
/// alargadas). Funciones puras (testeables).
class GbaLandscapeLayout {
  /// Lienzo base (4:3). Nunca se dibuja más pequeño que esto.
  static const double baseW = 360;
  static const double baseH = 270;

  /// Escena en coordenadas del área disponible (toda).
  final Rect viewport;

  /// Escala del lienzo de diseño a píxeles reales.
  final double scale;

  /// Tamaño del lienzo de diseño (con la escala da exactamente [viewport]).
  final double designW;
  final double designH;
  const GbaLandscapeLayout(this.viewport, this.scale, this.designW, this.designH);

  static GbaLandscapeLayout compute(Size area) {
    final w = math.max(area.width, 1.0);
    final h = math.max(area.height, 1.0);
    final scale = math.min(h / baseH, w / baseW);
    return GbaLandscapeLayout(Rect.fromLTWH(0, 0, w, h), scale, w / scale, h / scale);
  }
}
