// Generador del manual Word de PokéArena (OOXML mínimo, sin paquetes
// raros: solo `archive` para el ZIP). Uso:
//   dart run tool/generate_manual.dart
// Salida: carpeta pruebas/Manual_PokeArena.docx
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';

const _out =
    r'C:\Users\Usuario\Downloads\trabajos y protocos - 05 semestre\pruebas\Manual_PokeArena.docx';
const _base =
    r'C:\Users\Usuario\Downloads\trabajos y protocos - 05 semestre\DESARROLLO DE APPS\TCC_PokeAPI\pokearena';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// Dimensiones (w,h) de un PNG o JPEG leyendo la cabecera.
List<int> _imgSize(String path) {
  final b = File(path).readAsBytesSync();
  // PNG: firma de 8 + longitud + 'IHDR' + w(4) + h(4) big-endian.
  if (b.length > 26 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[4] == 0x49 &&
      b[5] == 0x48 &&
      b[6] == 0x44 &&
      b[7] == 0x52) {
    final w = (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
    final h = (b[20] << 24) | (b[21] << 16) | (b[22] << 8) | b[23];
    return [w, h];
  }
  // JPEG: busca el marcador SOF0/SOF2 (alto y ancho big-endian).
  var i = 2;
  while (i + 8 < b.length) {
    if (b[i] != 0xFF) {
      i++;
      continue;
    }
    final m = b[i + 1];
    if (m == 0xD8 || m == 0xD9 || (m >= 0xD0 && m <= 0xD7) || m == 0x01) {
      i += 2;
      continue;
    }
    if (m == 0xDA) break;
    final len = (b[i + 2] << 8) | b[i + 3];
    if (m == 0xC0 || m == 0xC2) {
      final h = (b[i + 5] << 8) | b[i + 6];
      final w = (b[i + 7] << 8) | b[i + 8];
      return [w, h];
    }
    i += 2 + len;
  }
  return [800, 600];
}

class _Doc {
  final List<String> body = [];
  final List<String> rels = [];
  final Map<String, String> media = {};
  int _rid = 0;

  void title(String t) => body.add(
      '<w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr><w:r><w:t>${_esc(t)}</w:t></w:r></w:p>');
  void h1(String t) => body.add(
      '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>${_esc(t)}</w:t></w:r></w:p>');
  void h2(String t) => body.add(
      '<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>${_esc(t)}</w:t></w:r></w:p>');
  void p(String t, {bool bold = false}) => body.add(
      '<w:p><w:pPr><w:pStyle w:val="Normal"/></w:pPr><w:r>${bold ? '<w:rPr><w:b/></w:rPr>' : ''}<w:t xml:space="preserve">${_esc(t)}</w:t></w:r></w:p>');
  void bullet(String t) => body.add(
      '<w:p><w:pPr><w:pStyle w:val="Normal"/></w:pPr><w:r><w:t xml:space="preserve">• ${_esc(t)}</w:t></w:r></w:p>');

  void table(List<List<String>> rows) {
    final sb = StringBuffer()
      ..write('<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
          '<w:tblBorders><w:top w:val="single" w:sz="4"/><w:left w:val="single" w:sz="4"/>'
          '<w:bottom w:val="single" w:sz="4"/><w:right w:val="single" w:sz="4"/>'
          '<w:insideH w:val="single" w:sz="4"/><w:insideV w:val="single" w:sz="4"/>'
          '</w:tblBorders></w:tblPr><w:tblGrid>');
    final n = rows.first.length;
    for (var i = 0; i < n; i++) {
      sb.write('<w:gridCol w:w="2880"/>');
    }
    sb.write('</w:tblGrid>');
    for (var r = 0; r < rows.length; r++) {
      sb.write('<w:tr>');
      for (final c in rows[r]) {
        sb.write('<w:tc><w:tcPr><w:shd w:fill="${r == 0 ? 'D9E2F3' : 'auto'}" w:val="clear"/></w:tcPr>'
            '<w:p><w:r>${r == 0 ? '<w:rPr><w:b/></w:rPr>' : ''}<w:t xml:space="preserve">${_esc(c)}</w:t></w:r></w:p></w:tc>');
      }
      sb.write('</w:tr>');
    }
    sb.write('</w:tbl>');
    body.add(sb.toString());
  }

  /// Imagen centrada, como máximo 5.8 pulgadas de ancho.
  void image(String assetRel, String alt) {
    final full = '$_base/$assetRel';
    final wh = _imgSize(full);
    const maxW = 5.8;
    final wIn = wh[0] / 160.0; // aprox. densidad típica de estos PNG
    final scale = wIn <= maxW ? 1.0 : maxW / wIn;
    final ew = (wh[0] * scale / 160 * 914400).round();
    final eh = (wh[1] * scale / 160 * 914400).round();
    final ext = full.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    _rid++;
    final id = 'rIdImg$_rid';
    final name = 'img$_rid.$ext';
    media[name] = full;
    rels.add(
        '<Relationship Id="$id" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/$name"/>');
    body.add('<w:p><w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:drawing xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">'
        '<wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$ew" cy="$eh"/>'
        '<wp:docPr id="$_rid" name="${_esc(alt)}"/>'
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:nvPicPr><pic:cNvPr id="$_rid" name="${_esc(alt)}"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="$id"/>'
        '<a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$ew" cy="$eh"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>');
  }
}

void main() {
  final d = _Doc();
  // ---- Portada ----
  d.title('PokéArena');
  d.p('Manual de usuario y técnico', bold: true);
  d.p('Proyecto de clase · Desarrollo de Apps · Juego RPG estilo Pokémon con PokeAPI');
  d.p('Octubre de 2026');
  d.image('assets/images/icons/logo_icon_1024.png', 'Logotipo PokéArena');

  // ---- 1. Qué es ----
  d.h1('1. Qué es PokéArena');
  d.p('PokéArena es un juego móvil hecho en Flutter: Pokédex con más de 1000 Pokémon, equipos, batallas por turnos (clásica GBA, arena 2.5D y en línea), quiz, monedero con desbloqueos, música de fondo y narrador por voz.');
  d.bullet('Pokédex: tarjetas por tipo, detalle, stats, gritos y evoluciones.');
  d.bullet('Equipo: hasta 6 con cobertura de tipos.');
  d.bullet('Batalla: modos Normal (GBA), 2.5D con 18 arenas y Online real.');
  d.bullet('Monedero: monedas por victoria para desbloquear avatares.');
  d.bullet('Quiz: siluetas con ranking y puntajes.');

  // ---- 2. Instalación ----
  d.h1('2. Instalación y primer arranque');
  d.bullet('Instala pokearena-debug.apk (permite orígenes desconocidos).');
  d.bullet('Splash nativo + intro de 3 pantallas con carga real y botón JUGAR.');
  d.bullet('Crea tu cuenta local (Entrar / Crear cuenta): equipo, monedas y ajustes quedan por usuario.');
  d.bullet('Solo la primera vez verás el onboarding de 3 tarjetas.');

  // ---- 3. Recorrido ----
  d.h1('3. Recorrido por la app');
  d.h2('3.1 Intro y menú');
  d.p('La intro precarga 60 artworks mientras muestra la secuencia; al terminar aparece JUGAR y arranca la música. Tocar adelanta las pantallas.');
  d.image('assets/images/splash/splash_1.jpg', 'Intro 1 Batalla');
  d.image('assets/images/splash/splash_2.png', 'Intro 2 Equipo');
  d.h2('3.2 Pokédex y candados');
  d.p('Los primeros 30 Pokémon están libres; el resto muestra candado. La carta bloqueada se puede abrir: ver sprite, stats y escuchar el grito. Solo agregar al equipo exige desbloquear con monedas.');
  d.h2('3.3 Equipo y batalla');
  d.p('Arma tu equipo de 6 y elige modo: Normal (GBA con 10 terrenos animados) o 2.5D (arena con perspectiva y 18 fondos). Gana para juntar monedas: 30/50/80 según dificultad.');
  d.h2('3.4 Quiz, Perfil y Ajustes');
  d.p('Quiz de siluetas con ranking; Perfil con favoritos e historial; Ajustes con fondos, sonidos, música con volumen y voz del narrador (♀/♂, volumen, velocidad, tono).');

  // ---- 4. Monedero ----
  d.h1('4. Monedero y desbloqueos');
  d.p('Cada victoria clásica da monedas según dificultad. Con ellas canjeas avatares bloqueados desde su detalle.');
  d.table([
    ['Generación (IDs)', 'Precio 🪙'],
    ['1–30', 'Libres'],
    ['31–151', '100'],
    ['152–251', '150'],
    ['252–386', '200'],
    ['387–493', '250'],
    ['494–649', '300'],
    ['650–721', '350'],
    ['722–809', '400'],
    ['810–905', '450'],
    ['906–1025', '500'],
  ]);

  // ---- 5. Sonido ----
  d.h1('5. Música y sonido');
  d.p('La música arranca sola al salir el botón JUGAR y suena en todo el juego salvo dentro de la arena (vuelve al terminar o salir). El volumen se ajusta en Ajustes; también hay switch de música y de sonido general.');

  // ---- 6. Arenas ----
  d.h1('6. Arenas de batalla');
  d.p('18 fondos en 2.5D (hierba, desierto, mazmorra, bosque rojo, cueva, nieve, ruinas, castillo, jungla, cementerio y variantes) y 10 animados en GBA (playa, bosque, noche, volcán, nieve, desierto, jungla, montaña, atardecer, tormenta).');
  d.image('assets/images/arenas/grass.png', 'Arena Hierba');
  d.image('assets/images/arenas/castle.png', 'Salón Dragón');
  d.image('assets/images/arenas/jungle.png', 'Jungla');

  // ---- 7. Arquitectura ----
  d.h1('7. Arquitectura técnica');
  d.p('Flutter + Provider por módulo, persistencia por usuario en SharedPreferences, PokeAPI por HTTP con caché, Firebase opcional. Verificado con flutter analyze limpio y suite de tests.');
  d.table([
    ['Módulo', 'Estado clave'],
    ['Auth', 'sesión local por usuario'],
    ['Pokedex/Equipo/Favoritos', 'datos y equipo por usuario'],
    ['Battle', 'turnos, IA, terrenos, GBA/2.5D/Online'],
    ['Wallet', 'monedas y desbloqueos por usuario'],
    ['Settings/Voice/Music', 'fondos, sonido, música, voz'],
    ['Splash', 'intro, onboarding, precarga'],
  ]);

  // ---- 8. Créditos ----
  d.h1('8. Créditos y licencias');
  d.bullet('Sprites y datos: PokeAPI (fan/educativo).');
  d.bullet('Fondos 2.5D: Nidhoggn (CC0) y CraftPix.net (OGA-BY 3.0).');
  d.bullet('Arte de logo e intro: material propio del equipo.');
  d.p('Proyecto académico: sin fines comerciales ni publicación con IP de terceros.');

  // ---- 9. Problemas ----
  d.h1('9. Solución de problemas');
  d.bullet('Imágenes nuevas no salen: reinstalar en limpio (los assets entran solo en instalación completa).');
  d.bullet('Sin red: funciona offline lo guardado; batallas bot y quiz local disponibles.');
  d.bullet('Sin sonido: revisar Sonido general y Música en Ajustes + volumen del teléfono.');
  d.bullet('En emulador se recomienda wipe data si algo visual no actualiza.');

  // ---- Empaquetado ----
  const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Default Extension="jpg" ContentType="image/jpeg"/><Default Extension="jpeg" ContentType="image/jpeg"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>''';
  const rels =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>''';
  const styles = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:style w:type="paragraph" w:styleId="Normal"><w:name w:val="Normal"/><w:rPr><w:sz w:val="22"/><w:szCs w:val="22"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:rPr><w:b/><w:sz w:val="56"/><w:szCs w:val="56"/><w:color w:val="C00000"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="Heading1"/><w:rPr><w:b/><w:sz w:val="32"/><w:szCs w:val="32"/><w:color w:val="2E5DB0"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="Heading2"/><w:rPr><w:b/><w:sz w:val="26"/><w:szCs w:val="26"/><w:color w:val="404040"/><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="ListBullet"><w:name w:val="ListBullet"/><w:rPr><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr></w:style></w:styles>''';

  final docRels =
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${d.rels.join()}</Relationships>';
  final doc =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><w:body>${d.body.join()}<w:sectPr><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body></w:document>';

  final archive = Archive();
  void addText(String path, String text) {
    archive.addFile(ArchiveFile(
        path, utf8.encode(text).length, utf8.encode(text)));
  }

  addText('[Content_Types].xml', contentTypes);
  addText('_rels/.rels', rels);
  addText('word/styles.xml', styles);
  addText('word/document.xml', doc);
  addText('word/_rels/document.xml.rels', docRels);
  d.media.forEach((name, full) {
    final bytes = File(full).readAsBytesSync();
    archive.addFile(ArchiveFile('word/media/$name', bytes.length, bytes));
  });

  final zip = ZipEncoder().encode(archive);
  File(_out).writeAsBytesSync(Uint8List.fromList(zip));
  // ignore: avoid_print
  print('Manual OK: $_out (${zip.length ~/ 1024} KB)');
}
