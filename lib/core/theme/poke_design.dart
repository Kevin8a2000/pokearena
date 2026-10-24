import 'package:flutter/material.dart';

/// Lenguaje visual "colores Pokémon": azul marino con Pokébolas, dorado, rojo
/// y crema. Todas las pantallas rediseñadas toman sus colores de aquí.
class PokeColors {
  static const navy = Color(0xFF14224C);
  static const navyDark = Color(0xFF0A1330);
  static const navyPanel = Color(0xFF111D45);
  static const gold = Color(0xFFF2B705);
  static const goldLight = Color(0xFFFFCB05);
  static const goldDark = Color(0xFFB98300);
  static const red = Color(0xFFD32F2F);
  static const redDark = Color(0xFF8E1B1B);
  static const redLight = Color(0xFFEF5350);
  static const cream = Color(0xFFF1E3C6);
  static const creamDark = Color(0xFFD9C79C);
  static const blue = Color(0xFF2A5DB0);
  static const panelBlue = Color(0xFF3B6FB6);
  static const ink = Color(0xFF14224C);
  static const white = Colors.white;
}

/// Familia de la fuente redondeada y gruesa (Lilita One, empaquetada en
/// `assets/fonts`). Si faltara, Flutter cae a la fuente del sistema.
const String kPokeFont = 'LilitaOne';

/// Estilo de texto de títulos, botones y números.
TextStyle pokeText(
  double size, {
  Color color = Colors.white,
  double? letterSpacing,
  double? height,
  List<Shadow>? shadows,
}) =>
    TextStyle(fontFamily: kPokeFont, fontSize: size, color: color, letterSpacing: letterSpacing, height: height, shadows: shadows);

/// Sombra suave para texto blanco sobre fondos de color.
const pokeTextShadow = [Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1.5))];
