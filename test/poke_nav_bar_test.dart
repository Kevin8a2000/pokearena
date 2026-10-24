import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/features/home/poke_nav_bar.dart';

const _labels = ['Pokédex', 'Equipo', 'Batalla', 'Quiz', 'Perfil', 'Ajustes'];

/// Pantalla de pruebas con la barra y un indicador de la pestaña activa.
class _Host extends StatefulWidget {
  final int initial;
  const _Host({this.initial = 0});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int index = widget.initial;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: Text('pestaña $index', key: const ValueKey('tab'))),
        bottomNavigationBar: PokeNavBar(index: index, onTap: (i) => setState(() => index = i)),
      ),
    );
  }
}

void main() {
  Future<void> open(WidgetTester tester, {Size size = const Size(420, 800), int initial = 0}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_Host(initial: initial));
  }

  testWidgets('muestra los 6 destinos en orden con su etiqueta', (tester) async {
    await open(tester);
    expect(pokeNavDestinations.map((d) => d.label), _labels);
    for (final l in _labels) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
    final xs = [for (final l in _labels) tester.getCenter(find.text(l)).dx];
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], greaterThan(xs[i - 1]), reason: 'orden de izquierda a derecha');
    }
    // Mismo ancho para todos.
    final w = tester.getSize(find.byType(PokeNavBar)).width / 6;
    for (var i = 0; i < 6; i++) {
      expect(xs[i], closeTo(w * i + w / 2, 3));
    }
  });

  testWidgets('tocar un destino cambia de pestaña y lo marca como activo', (tester) async {
    await open(tester);
    expect(find.text('pestaña 0'), findsOneWidget);
    for (var i = 1; i < 6; i++) {
      await tester.tap(find.text(_labels[i]));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('pestaña $i'), findsOneWidget);
    }
    await tester.tap(find.text('Pokédex'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('pestaña 0'), findsOneWidget);
  });

  testWidgets('tocar el icono (no solo la etiqueta) también funciona', (tester) async {
    await open(tester);
    final tile = tester.getRect(find.ancestor(of: find.text('Quiz'), matching: find.byType(GestureDetector)).first);
    await tester.tapAt(Offset(tile.center.dx, tile.top + 12));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('pestaña 3'), findsOneWidget);
  });

  testWidgets('el activo va en cuadrado rojo con borde dorado y los demás no', (tester) async {
    await open(tester, initial: 2);
    BoxDecoration deco(String label) {
      final c = tester.widget<AnimatedContainer>(find.ancestor(of: find.text(label), matching: find.byType(AnimatedContainer)).first);
      return c.decoration! as BoxDecoration;
    }

    expect(deco('Batalla').border!.top.color, PokeNavBar.gold);
    expect(deco('Batalla').gradient, isNotNull, reason: 'relleno rojo');
    expect(deco('Equipo').border!.top.color.a, 0);
    expect(deco('Equipo').gradient, isNull);
  });

  testWidgets('semántica: cada destino es un botón con etiqueta y el activo está seleccionado', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, initial: 1);
    for (final l in _labels) {
      final node = tester.getSemantics(find.bySemanticsLabel(l));
      expect(node.flagsCollection.isButton, isTrue, reason: l);
      expect(node.flagsCollection.isSelected == Tristate.isTrue, l == 'Equipo', reason: l);
    }
    handle.dispose();
  });

  testWidgets('la barra es alta y con filo dorado arriba, y los destinos son fáciles de tocar', (tester) async {
    await open(tester);
    final bar = tester.getSize(find.byType(PokeNavBar));
    expect(bar.height, greaterThanOrEqualTo(76));
    final deco = tester.widget<DecoratedBox>(find.descendant(of: find.byType(PokeNavBar), matching: find.byType(DecoratedBox)).first).decoration as BoxDecoration;
    expect(deco.border!.top.color, PokeNavBar.gold);
    for (final l in _labels) {
      final r = tester.getRect(find.ancestor(of: find.text(l), matching: find.byType(GestureDetector)).first);
      expect(r.height, greaterThanOrEqualTo(48), reason: l);
      expect(r.width, greaterThanOrEqualTo(48), reason: l);
    }
  });

  for (final size in const [Size(320, 640), Size(360, 740), Size(420, 800), Size(800, 360), Size(1280, 800)]) {
    testWidgets('sin overflow a ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await open(tester, size: size);
      expect(tester.takeException(), isNull);
      for (final l in _labels) {
        final r = tester.getRect(find.text(l));
        expect(r.left, greaterThanOrEqualTo(0), reason: l);
        expect(r.right, lessThanOrEqualTo(size.width), reason: l);
      }
    });
  }

  testWidgets('los iconos se dibujan todos (Pokébola, equipo, guante, quiz, entrenador y engranaje)', (tester) async {
    await open(tester);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byIcon(Icons.groups), findsWidgets);
    expect(find.byIcon(Icons.sports_mma), findsWidgets);
    expect(find.byIcon(Icons.settings), findsWidgets);
    expect(find.text('?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
