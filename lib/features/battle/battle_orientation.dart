import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Obliga a jugar los combates en horizontal: al empezar uno, el teléfono
/// rota solo a apaisado (izquierda o derecha) y se oculta la barra del sistema
/// para ganar espacio; al terminar se restauran las orientaciones libres.
///
/// Usa un **contador**: varios consumidores pueden pedir el bloqueo a la vez
/// (el combate local y la pantalla online) y la orientación solo se restaura
/// cuando el último lo suelta.
class BattleOrientation {
  BattleOrientation._();

  /// Orientaciones permitidas durante el combate.
  static const landscape = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static int _locks = 0;

  /// Cuántos consumidores mantienen el bloqueo ahora mismo.
  static int get locks => _locks;

  static bool get isLocked => _locks > 0;

  /// Pide el modo horizontal. Solo la primera petición toca el sistema.
  static void lock() {
    _locks++;
    if (_locks != 1) return;
    SystemChrome.setPreferredOrientations(landscape);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Suelta el modo horizontal. Solo cuando ya nadie lo pide se restaura la
  /// orientación libre y las barras del sistema. Soltar de más no hace nada.
  static void release() {
    if (_locks == 0) return;
    _locks--;
    if (_locks != 0) return;
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
  }

  /// Solo para pruebas: deja el contador a cero sin tocar el sistema.
  @visibleForTesting
  static void debugReset() => _locks = 0;
}

/// Mantiene la pantalla en horizontal mientras está montado (se usa en la
/// batalla online; el combate local lo gestiona el `BattleProvider`).
class LandscapeLock extends StatefulWidget {
  final Widget child;
  const LandscapeLock({super.key, required this.child});

  @override
  State<LandscapeLock> createState() => _LandscapeLockState();
}

class _LandscapeLockState extends State<LandscapeLock> {
  @override
  void initState() {
    super.initState();
    BattleOrientation.lock();
  }

  @override
  void dispose() {
    BattleOrientation.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
