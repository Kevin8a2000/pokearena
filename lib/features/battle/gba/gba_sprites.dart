import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Hojas de sprites FRLG de la batalla Normal (vista GBA).
///
/// Las hojas traen un color marcador (naranja `#FF7F27` en Entrenadores,
/// rosa `#FFA6A6` en Poké Balls) en vez de transparencia, así que al cargar
/// se vuelve transparente. Medidas verificadas sobre los PNG:
/// - **trainers.png** (536x1400): celdas de 64x64 con paso 65, primera celda
///   en x=8, separadas por 1 px blanco. Espalda de Red (y=967) y Leaf (y=1032)
///   con 5 cuadros de lanzamiento; frentes de entrenadores en las filas
///   de [frontRows].
/// - **poke_balls.png** (192x100): 12 tipos de bola en columnas de paso 16
///   (x = 2 + 16*tipo, 12 px de ancho) y 3 filas: cerrada (y=21, alto 12),
///   abriéndose (y=38, alto 13) y abierta (y=55, alto 16).
class GbaSprites {
  GbaSprites._();

  static const _dir = 'assets/images/battle/';
  static const trainersAsset = '${_dir}trainers.png';
  static const ballsAsset = '${_dir}poke_balls.png';

  static const attackFxAsset = '${_dir}attack_fx.png';
  static const platformsAsset = 'assets/images/arenas/gba_battle_platforms.png';

  static const trainerMarkers = [0xFF7F27];
  static const ballMarkers = [0xFFA6A6];
  static const fxMarkers = [0x22B14C];
  // Hoja opaca (fondo propio en cada celda): no hay color marcador que quitar.
  static const platformMarkers = <int>[];

  static ui.Image? _trainers;
  static ui.Image? _balls;
  static ui.Image? _fx;
  static ui.Image? _platforms;
  static Future<void>? _loading;

  static bool get trainersLoaded => _trainers != null;
  static bool get ballsLoaded => _balls != null;
  static bool get fxLoaded => _fx != null;
  static bool get platformsLoaded => _platforms != null;
  static ui.Image? get trainers => _trainers;
  static ui.Image? get balls => _balls;
  static ui.Image? get attackFx => _fx;
  static ui.Image? get platforms => _platforms;

  /// Carga las hojas una sola vez. Si alguna falla, esa pieza se dibuja por
  /// código (la batalla sigue funcionando sin sprites).
  static Future<void> load() => _loading ??= _loadAll();

  static Future<void> _loadAll() async {
    final results = await Future.wait([
      _loadSheet(trainersAsset, trainerMarkers),
      _loadSheet(ballsAsset, ballMarkers),
      _loadSheet(attackFxAsset, fxMarkers),
      _loadSheet(platformsAsset, platformMarkers),
    ]);
    _trainers = results[0];
    _balls = results[1];
    _fx = results[2];
    _platforms = results[3];
  }

  static Future<ui.Image?> _loadSheet(String asset, List<int> markers) async {
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final raw = (await codec.getNextFrame()).image;
      final bytes = (await raw.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final pixels = bytes.buffer.asUint8List().sublist(0);
      keyOut(pixels, markers);
      final c = Completer<ui.Image>();
      ui.decodeImageFromPixels(pixels, raw.width, raw.height, ui.PixelFormat.rgba8888, c.complete);
      return await c.future;
    } catch (_) {
      return null;
    }
  }

  /// Deja en (0,0,0,0) los píxeles cuyo RGB está en [markers].
  ///
  /// Tiene que ser transparente de verdad: Flutter trata estos bytes como
  /// alfa premultiplicado, y un píxel con alfa 0 pero RGB distinto de cero
  /// se SUMA al fondo (se veía como un recuadro de color).
  static void keyOut(List<int> rgba, List<int> markers) {
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      final rgb = (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2];
      if (markers.contains(rgb)) {
        rgba[i] = 0;
        rgba[i + 1] = 0;
        rgba[i + 2] = 0;
        rgba[i + 3] = 0;
      }
    }
  }

  // ------------------------------------------------------------ Entrenadores

  static const trainerCell = 64.0;
  static const trainerStep = 65.0;
  static const trainerOriginX = 8.0;
  static const _redBackY = 967.0;
  static const _leafBackY = 1032.0;

  /// Cuadros de la espalda al lanzar la Poké Ball (0..4).
  static const throwFrames = 5;

  /// Espalda de Red (chico) o Leaf (chica) en el cuadro [frame] del lanzamiento.
  static ui.Rect trainerBack({required bool female, required int frame}) => ui.Rect.fromLTWH(
        trainerOriginX + trainerStep * frame.clamp(0, throwFrames - 1),
        female ? _leafBackY : _redBackY,
        trainerCell,
        trainerCell,
      );

  /// Filas de entrenadores de frente: (y de la fila, nº de celdas).
  static const _regularRows = <(double, int)>[(242, 8), (307, 8), (372, 8), (437, 8), (502, 8), (567, 6)];
  static const _rivalRow = (142.0, 3);
  static const _leaderRows = <(double, int)>[(667, 8), (767, 4)]; // líderes de gimnasio + Alto Mando

  static ui.Rect _cell((double, int) row, int i) => ui.Rect.fromLTWH(trainerOriginX + trainerStep * i, row.$1, trainerCell, trainerCell);

  /// Nº de entrenadores de frente disponibles por nivel de dificultad
  /// (0 = fácil, 1 = normal, 2 = difícil).
  static int frontCount(int tier) => switch (tier) {
        0 => _regularRows.fold(0, (s, r) => s + r.$2),
        1 => _rivalRow.$2,
        _ => _leaderRows.fold(0, (s, r) => s + r.$2),
      };

  /// Entrenador de frente para el rival: fácil → entrenador común, normal →
  /// el Rival, difícil → líder de gimnasio o del Alto Mando. [seed] elige uno
  /// de forma estable (p. ej. el id del Pokémon rival).
  static ui.Rect trainerFront({required int tier, required int seed}) {
    final rows = switch (tier) {
      0 => _regularRows,
      1 => [_rivalRow],
      _ => _leaderRows,
    };
    var i = seed.abs() % frontCount(tier);
    for (final r in rows) {
      if (i < r.$2) return _cell(r, i);
      i -= r.$2;
    }
    return _cell(rows.first, 0);
  }

  // ------------------------------------------------------------- Poké Balls

  /// Poké Ball clásica (roja) en la hoja.
  static const pokeBallType = 2;

  /// [stage]: 0 = cerrada, 1 = abriéndose, 2 = abierta.
  static ui.Rect ball({int type = pokeBallType, required int stage}) {
    const ys = [21.0, 38.0, 55.0];
    const hs = [12.0, 13.0, 16.0];
    final s = stage.clamp(0, 2);
    return ui.Rect.fromLTWH(2.0 + 16.0 * type, ys[s], 12, hs[s]);
  }
}

/// Plataformas circulares de combate (hoja `gba_battle_platforms.png`,
/// 737x466, grid de 3 columnas x 4 filas, celdas de 240x112 separadas por
/// líneas granate). 10 celdas útiles — la de fila 3/col 1-2 es un cartel de
/// créditos, no una plataforma. Cada celda trae también su propio cielo de
/// fondo; el aro de la plataforma solo ocupa una franja chica (medida sobre
/// el PNG) dentro de ella, así que se recorta solo esa franja —no la celda
/// completa— para que al estirarla sobre el óvalo de destino se vea el aro,
/// no el fondo diluido. [forTerrain] asigna una celda a cada uno de los 10
/// terrenos de [gbaTerrains] por tono de color.
///
/// Créditos: ripeado de Pokémon FireRed/LeafGreen por *Desgardes* (texto
/// incluido en la propia imagen: "ripped by Desgardes. No credit needed").
/// Es de Nintendo/Game Freak: válido para el proyecto de clase, no para
/// publicar en tiendas.
class GbaPlatforms {
  GbaPlatforms._();

  static const _colX = [6.0, 249.0, 492.0];
  static const _rowY = [6.0, 121.0, 235.0, 349.0];

  // El aro, dentro de cada celda de 240x112, cae en esta franja (medida a
  // ojo sobre el PNG a 4x): local x 110..240, y 40..84.
  static const _ringOffsetX = 110.0;
  static const _ringOffsetY = 40.0;
  static const _ringW = 130.0;
  static const _ringH = 44.0;

  static ui.Rect _tile(int row, int col) => ui.Rect.fromLTWH(_colX[col] + _ringOffsetX, _rowY[row] + _ringOffsetY, _ringW, _ringH);

  /// Celda (fila, columna) por id de terreno GBA.
  static const Map<String, (int, int)> _byTerrainId = {
    'gba-montana': (0, 0),
    'gba-bosque': (0, 1),
    'gba-playa': (0, 2),
    'gba-volcan': (1, 0),
    'gba-jungla': (1, 1),
    'gba-noche': (1, 2),
    'gba-desierto': (2, 0),
    'gba-atardecer': (2, 1),
    'gba-tormenta': (2, 2),
    'gba-nieve': (3, 0),
  };

  /// Recorte de la plataforma para [terrainId]; null si no hay mapeo.
  static ui.Rect? forTerrain(String terrainId) {
    final rc = _byTerrainId[terrainId];
    return rc == null ? null : _tile(rc.$1, rc.$2);
  }
}

/// Efectos de ataque (hoja `attack_fx.png`, 948x835, fondo verde `#22B14C`).
///
/// La hoja es un atlas irregular (sprites sueltos); estos rectángulos se
/// detectaron por componentes conexos y se verificaron a ojo. Para cada tipo
/// de movimiento hay una lista de sprites que se esparcen al impactar; en
/// [fxSequenceTypes] el primer sprite(s) forman una animación en orden.
///
/// Créditos: sprites de ataque ripeados por *wormintheworks*
/// (gmhandbk.webs.com). Son de Nintendo/Game Freak: válidos para el proyecto
/// de clase, no para publicar en tiendas.
class GbaFx {
  GbaFx._();


  static const Map<String, List<ui.Rect>> byType = {
    'normal': [ui.Rect.fromLTWH(744, 348, 29, 27), ui.Rect.fromLTWH(757, 248, 16, 17), ui.Rect.fromLTWH(746, 387, 15, 18)],
    // Explosión en 3 cuadros (32x32) + chispa pequeña.
    'fire': [ui.Rect.fromLTWH(480, 435, 32, 32), ui.Rect.fromLTWH(480, 467, 32, 32), ui.Rect.fromLTWH(480, 499, 32, 32), ui.Rect.fromLTWH(757, 248, 16, 17)],
    'water': [ui.Rect.fromLTWH(817, 329, 12, 30), ui.Rect.fromLTWH(279, 486, 20, 22), ui.Rect.fromLTWH(407, 638, 16, 42), ui.Rect.fromLTWH(63, 5, 24, 26)],
    'grass': [ui.Rect.fromLTWH(924, 111, 8, 12), ui.Rect.fromLTWH(926, 93, 7, 14), ui.Rect.fromLTWH(921, 128, 11, 10), ui.Rect.fromLTWH(921, 148, 13, 8), ui.Rect.fromLTWH(920, 161, 13, 10), ui.Rect.fromLTWH(922, 189, 10, 30)],
    'electric': [ui.Rect.fromLTWH(372, 737, 102, 32), ui.Rect.fromLTWH(224, 438, 20, 30), ui.Rect.fromLTWH(218, 468, 32, 32)],
    'ice': [ui.Rect.fromLTWH(429, 317, 26, 30), ui.Rect.fromLTWH(429, 348, 26, 30), ui.Rect.fromLTWH(430, 382, 27, 29), ui.Rect.fromLTWH(273, 547, 32, 31), ui.Rect.fromLTWH(277, 516, 25, 27)],
    'fighting': [ui.Rect.fromLTWH(543, 457, 21, 30), ui.Rect.fromLTWH(744, 348, 29, 27)],
    'flying': [ui.Rect.fromLTWH(315, 358, 32, 15), ui.Rect.fromLTWH(315, 328, 32, 13), ui.Rect.fromLTWH(749, 172, 21, 9), ui.Rect.fromLTWH(751, 314, 21, 26)],
    'poison': [ui.Rect.fromLTWH(698, 229, 11, 26), ui.Rect.fromLTWH(697, 290, 11, 29), ui.Rect.fromLTWH(381, 471, 16, 48)],
    'ground': [ui.Rect.fromLTWH(805, 203, 14, 17), ui.Rect.fromLTWH(805, 235, 10, 11), ui.Rect.fromLTWH(800, 171, 20, 18)],
    'rock': [ui.Rect.fromLTWH(799, 99, 25, 27), ui.Rect.fromLTWH(800, 132, 22, 26), ui.Rect.fromLTWH(800, 171, 20, 18), ui.Rect.fromLTWH(472, 542, 27, 23)],
    'bug': [ui.Rect.fromLTWH(596, 444, 17, 16), ui.Rect.fromLTWH(591, 464, 26, 21), ui.Rect.fromLTWH(592, 494, 27, 16)],
    'ghost': [ui.Rect.fromLTWH(542, 508, 24, 32), ui.Rect.fromLTWH(566, 587, 30, 32), ui.Rect.fromLTWH(900, 275, 16, 14), ui.Rect.fromLTWH(900, 293, 16, 12)],
    'steel': [ui.Rect.fromLTWH(221, 328, 20, 66), ui.Rect.fromLTWH(224, 438, 20, 30), ui.Rect.fromLTWH(218, 468, 32, 32)],
    'psychic': [ui.Rect.fromLTWH(900, 275, 16, 14), ui.Rect.fromLTWH(900, 293, 16, 12), ui.Rect.fromLTWH(566, 587, 30, 32)],
    'dragon': [ui.Rect.fromLTWH(327, 518, 31, 20), ui.Rect.fromLTWH(327, 550, 43, 20), ui.Rect.fromLTWH(429, 559, 17, 16)],
    'dark': [ui.Rect.fromLTWH(427, 207, 26, 27), ui.Rect.fromLTWH(427, 239, 27, 28), ui.Rect.fromLTWH(427, 271, 29, 31)],
    'fairy': [ui.Rect.fromLTWH(431, 528, 13, 13), ui.Rect.fromLTWH(427, 590, 21, 19), ui.Rect.fromLTWH(429, 559, 17, 16)],
  };

  /// Tipos cuyos primeros [sequenceFrames] sprites se reproducen en orden.
  static const Map<String, int> sequenceFrames = {'fire': 3};

  /// Sprites del tipo (con "normal" de respaldo para tipos desconocidos).
  static List<ui.Rect> forType(String type) => byType[type.toLowerCase()] ?? byType['normal']!;

  /// Cuadros de la animación del tipo (vacía si no tiene).
  static List<ui.Rect> sequenceFor(String type) {
    final n = sequenceFrames[type.toLowerCase()] ?? 0;
    return n == 0 ? const [] : forType(type).sublist(0, n);
  }

  /// Sprites sueltos que se esparcen (sin los de la secuencia).
  static List<ui.Rect> particlesFor(String type) {
    final n = sequenceFrames[type.toLowerCase()] ?? 0;
    final all = forType(type);
    return n == 0 ? all : all.sublist(n);
  }
}
