import 'package:flutter/material.dart';

import '../theme/poke_design.dart';
import '../theme/type_colors.dart';
import 'pokeball_background.dart';

/// Componentes del diseño "colores Pokémon": títulos tipo logo, paneles con
/// borde dorado, botones rojos 3D, segmentados, interruptores y deslizadores
/// con Pokébola.

// ----------------------------------------------------------------- Pokébola

/// Pokébola completa: mitad roja, mitad blanca, banda negra y botón.
class PokeBallIcon extends StatelessWidget {
  final double size;
  const PokeBallIcon({super.key, required this.size});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: const PokeBallPaint());
}

/// Pintor de la Pokébola completa (también se usa como pulgar de deslizadores).
class PokeBallPaint extends CustomPainter {
  const PokeBallPaint();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, 3.14159, 3.14159, true, Paint()..color = const Color(0xFFE53935));
    canvas.drawArc(rect, 0, 3.14159, true, Paint()..color = Colors.white);
    final dark = Paint()
      ..color = const Color(0xFF1B1B1B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09;
    canvas.drawCircle(c, r, dark);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), dark);
    canvas.drawCircle(c, r * 0.30, Paint()..color = Colors.white);
    canvas.drawCircle(c, r * 0.30, dark);
    canvas.drawCircle(c, r * 0.12, Paint()..color = const Color(0xFFB0BEC5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ------------------------------------------------------------------- Títulos

/// Título estilo logo Pokémon: amarillo con contorno azul y sombra. Con
/// [arched] cada letra se curva ligeramente (arco hacia arriba).
class PokeLogoText extends StatelessWidget {
  final String text;
  final double size;
  final bool arched;
  final Color fill;
  final Color stroke;
  const PokeLogoText(this.text, {super.key, this.size = 34, this.arched = false, this.fill = PokeColors.goldLight, this.stroke = PokeColors.blue});

  Widget _layers(String s) {
    TextStyle style({Paint? fg, Color? color}) => TextStyle(fontFamily: kPokeFont, fontSize: size, letterSpacing: size * 0.02, foreground: fg, color: fg == null ? color : null);
    return Stack(
      children: [
        Transform.translate(offset: Offset(0, size * 0.09), child: Text(s, style: style(fg: Paint()..style = PaintingStyle.fill..color = Colors.black54))),
        Text(
          s,
          style: style(
            fg: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.16
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
          ),
        ),
        Text(s, style: style(color: fill)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!arched) {
      return Semantics(label: text, excludeSemantics: true, child: _layers(text));
    }
    final n = text.length;
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < n; i++)
              Builder(builder: (_) {
                final t = n <= 1 ? 0.0 : (i - (n - 1) / 2) / ((n - 1) / 2);
                return Transform.translate(
                  offset: Offset(0, t * t * size * 0.22),
                  child: Transform.rotate(angle: t * 0.14, child: _layers(text[i])),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Texto blanco con contorno negro (para titulares sobre fondos vivos).
class PokeOutlinedText extends StatelessWidget {
  final String text;
  final double size;
  final Color fill;
  final Color stroke;
  final TextAlign align;
  const PokeOutlinedText(this.text, {super.key, this.size = 40, this.fill = Colors.white, this.stroke = Colors.black, this.align = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    TextStyle style({Paint? fg, Color? color}) => TextStyle(fontFamily: kPokeFont, fontSize: size, height: 1.05, foreground: fg, color: fg == null ? color : null);
    return Stack(
      children: [
        Text(
          text,
          textAlign: align,
          style: style(
            fg: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.2
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
          ),
        ),
        Text(text, textAlign: align, style: style(color: fill)),
      ],
    );
  }
}

// ---------------------------------------------------------------- Estructura

/// Pantalla base: fondo azul marino con Pokébolas (o el que se indique),
/// `SafeArea` y cabecera propia (título + acciones) en lugar de `AppBar`.
class PokeScaffold extends StatelessWidget {
  final Widget? title;
  final List<Widget> actions;
  final Widget body;
  final Widget? background;
  final bool centerTitle;
  const PokeScaffold({super.key, this.title, this.actions = const [], required this.body, this.background, this.centerTitle = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PokeColors.navyDark,
      body: Stack(
        children: [
          Positioned.fill(child: background ?? const PokeballBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (title != null || actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: centerTitle
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              if (title != null) Center(child: title),
                              if (actions.isNotEmpty) Align(alignment: Alignment.centerRight, child: Row(mainAxisSize: MainAxisSize.min, children: actions)),
                            ],
                          )
                        : Row(
                            children: [
                              if (title != null) Expanded(child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: title))),
                              for (final a in actions) Padding(padding: const EdgeInsets.only(left: 8), child: a),
                            ],
                          ),
                  ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel azul marino con borde dorado y esquinas muy redondeadas.
class PokePanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color border;
  final double radius;
  const PokePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = PokeColors.navyPanel,
    this.border = PokeColors.gold,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}

// ------------------------------------------------------------------- Botones

/// Botón rojo 3D con borde oscuro y texto blanco (opcionalmente con flecha).
class PokeButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool arrow;
  final double height;
  final double fontSize;
  final Color color;
  final Color darkColor;
  final bool expanded;
  const PokeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.arrow = false,
    this.height = 46,
    this.fontSize = 18,
    this.color = PokeColors.red,
    this.darkColor = PokeColors.redDark,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Container(
            height: height,
            width: expanded ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: height * 0.45),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(color, Colors.white, 0.18)!, color]),
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: const Color(0xFF3A0A0A), width: 2.5),
              boxShadow: [BoxShadow(color: darkColor, offset: const Offset(0, 4)), const BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 6))],
            ),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, color: Colors.white, size: fontSize * 1.2), const SizedBox(width: 6)],
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: pokeText(fontSize, shadows: pokeTextShadow))),
                if (arrow) ...[const SizedBox(width: 6), Icon(Icons.arrow_forward, color: Colors.white, size: fontSize * 1.1)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón redondo rojo con icono (p. ej. ▶ "Probar voz").
class PokeRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;
  const PokeRoundButton({super.key, required this.icon, required this.onPressed, this.size = 56, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [PokeColors.redLight, PokeColors.red]),
            border: Border.all(color: const Color(0xFF3A0A0A), width: 2.5),
            boxShadow: const [BoxShadow(color: PokeColors.redDark, offset: Offset(0, 4)), BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 6))],
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.6),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- Segmentados

/// Opción de un [PokeSegmented].
class PokeSegment<T> {
  final T value;
  final String label;
  final IconData? icon;
  const PokeSegment(this.value, this.label, {this.icon});
}

/// Segmentado rojo/crema: el elegido va en rojo con ✓ y los demás en crema.
class PokeSegmented<T> extends StatelessWidget {
  final List<PokeSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;
  const PokeSegmented({super.key, required this.segments, required this.selected, required this.onChanged, this.height = 46});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2 - 2),
        border: Border.all(color: Colors.black, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2 - 5),
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0) Container(width: 2, color: Colors.black),
              Expanded(child: _Seg<T>(seg: segments[i], selected: segments[i].value == selected, onTap: () => onChanged(segments[i].value))),
            ],
          ],
        ),
      ),
    );
  }
}

class _Seg<T> extends StatelessWidget {
  final PokeSegment<T> seg;
  final bool selected;
  final VoidCallback onTap;
  const _Seg({required this.seg, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : PokeColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: seg.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          color: selected ? PokeColors.red : PokeColors.cream,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[Icon(Icons.check, color: fg, size: 20), const SizedBox(width: 4)] else if (seg.icon != null) ...[Icon(seg.icon, color: fg, size: 18), const SizedBox(width: 4)],
                Text(seg.label, style: pokeText(17, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------- Interruptor / radio / slider

/// Interruptor con Pokébola como pulgar: rojo encendido, gris apagado.
class PokeSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const PokeSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 62,
          height: 34,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? PokeColors.red : const Color(0xFF9E9E9E),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 2))],
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: const PokeBallIcon(size: 26),
          ),
        ),
      ),
    );
  }
}

/// Fila "título + subtítulo + interruptor Pokébola".
class PokeSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double titleSize;
  const PokeSwitchTile({super.key, required this.title, this.subtitle, this.icon, required this.value, required this.onChanged, this.titleSize = 19});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, color: PokeColors.gold, size: 26), const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: pokeText(titleSize)),
                if (subtitle != null) Text(subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PokeSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Radio con Pokébola: seleccionado = bola roja y blanca; si no, círculo vacío.
class PokeRadio<T> extends StatelessWidget {
  final T value;
  final T? groupValue;
  final ValueChanged<T> onChanged;
  final Widget label;
  const PokeRadio({super.key, required this.value, required this.groupValue, required this.onChanged, required this.label});

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: Colors.black, width: 2.5)),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? PokeColors.red : Colors.transparent,
                    border: Border.all(color: selected ? Colors.black : Colors.transparent, width: 2),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              label,
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulgar del deslizador: Pokébola con contorno.
class PokeSliderThumb extends SliderComponentShape {
  final double radius;
  const PokeSliderThumb({this.radius = 15});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(center.dx - radius, center.dy - radius);
    canvas.drawCircle(Offset(radius, radius + 2), radius, Paint()..color = Colors.black38);
    const PokeBallPaint().paint(canvas, Size.square(radius * 2));
    canvas.restore();
  }
}

/// Tema de deslizador del diseño: pista roja/crema y pulgar Pokébola.
SliderThemeData pokeSliderTheme(BuildContext context) => SliderTheme.of(context).copyWith(
      trackHeight: 9,
      activeTrackColor: PokeColors.red,
      inactiveTrackColor: PokeColors.cream,
      thumbShape: const PokeSliderThumb(),
      overlayColor: PokeColors.red.withValues(alpha: 0.2),
      trackShape: const RoundedRectSliderTrackShape(),
    );

/// Deslizador con el estilo del diseño.
class PokeSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  const PokeSlider({super.key, required this.value, required this.onChanged, this.min = 0, this.max = 1, this.divisions});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: pokeSliderTheme(context),
      child: Slider(value: value.clamp(min, max).toDouble(), min: min, max: max, divisions: divisions, onChanged: onChanged),
    );
  }
}

// ---------------------------------------------------------------------- Tipos

/// Etiqueta de tipo: la del 1.er tipo en blanco translúcido sobre la tarjeta
/// del mismo color y la del 2.º con el color de su tipo.
class TypePill extends StatelessWidget {
  final String type;
  final bool primary;
  final double fontSize;
  const TypePill({super.key, required this.type, this.primary = true, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    final color = colorForType(type);
    final dark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize, vertical: fontSize * 0.32),
      decoration: BoxDecoration(
        color: primary ? Colors.white.withValues(alpha: 0.28) : color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: primary ? 0.0 : 0.6), width: 1.2),
      ),
      child: Text(
        typeNameEs(type),
        maxLines: 1,
        style: TextStyle(color: primary || dark ? Colors.white : PokeColors.ink, fontSize: fontSize, fontWeight: FontWeight.w800),
      ),
    );
  }
}

// ------------------------------------------------------------------- Volver

/// Botón "volver": cuadrado blanco con flecha negra y borde negro.
class PokeBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const PokeBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Volver',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed ?? () => Navigator.of(context).maybePop(),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 2.5),
            boxShadow: const [BoxShadow(color: Colors.black45, offset: Offset(0, 3))],
          ),
          child: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
        ),
      ),
    );
  }
}
