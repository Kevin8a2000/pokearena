import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/services/narrator_voices.dart';

NarratorVoice v(String name, String locale, VoiceGender g) =>
    NarratorVoice(name: name, locale: locale, gender: g);

void main() {
  List<NarratorVoice> catalog() => [
        // Español: 4 hembras, 2 machos, 2 neutras, + otros idiomas.
        v('es-f1', 'es-ES', VoiceGender.female),
        v('es-f2', 'es-ES', VoiceGender.female),
        v('es-f3', 'es-MX', VoiceGender.female),
        v('es-f4', 'es-ES', VoiceGender.female),
        v('es-m1', 'es-ES', VoiceGender.male),
        v('es-m2', 'es-ES', VoiceGender.male),
        v('es-x1', 'es-ES', VoiceGender.unknown),
        v('es-x2', 'es-ES', VoiceGender.unknown),
        v('en-f1', 'en-US', VoiceGender.female),
        v('en-m1', 'en-US', VoiceGender.male),
        v('en-m2', 'en-GB', VoiceGender.male),
        v('en-x1', 'en-US', VoiceGender.unknown),
        v('fr-f1', 'fr-FR', VoiceGender.female),
        v('de-m1', 'de-DE', VoiceGender.male),
        v('pt-f1', 'pt-BR', VoiceGender.female),
        v('Zulu', 'zu-ZA', VoiceGender.female),
      ];

  test('solo inglés y español, máximo 12', () {
    final out = curateNarratorCatalog(catalog());
    expect(out.length, lessThanOrEqualTo(12));
    for (final voice in out) {
      final lang =
          voice.locale.split(RegExp('[-_]')).first.toLowerCase();
      expect(['es', 'en'], contains(lang));
    }
  });

  test('3 por grupo con relleno neutro', () {
    final out = curateNarratorCatalog(catalog());
    String langOf(NarratorVoice e) =>
        e.locale.split(RegExp('[-_]')).first.toLowerCase();
    final es = out.where((e) => langOf(e) == 'es').toList();
    // Hembras: 3 de 4 (alfabéticas). Machos: 2 + 1 neutra de relleno.
    expect(es.where((e) => e.gender == VoiceGender.female), hasLength(3));
    expect(
      es.where((e) => e.name == 'es-f4'),
      isEmpty,
    );
    expect(es.where((e) => e.gender == VoiceGender.male), hasLength(2));
    expect(es.where((e) => e.gender == VoiceGender.unknown), hasLength(1));
    // Inglés: 1 hembra + 2 machos + 1 neutra de relleno (1+2+1=4).
    final en = out.where((e) => langOf(e) == 'en').toList();
    expect(en, hasLength(4));
    expect(out, hasLength(10));
  });

  test('determinista y sin duplicados', () {
    final a = curateNarratorCatalog(catalog());
    final b = curateNarratorCatalog(catalog());
    expect(
      [for (final e in a) e.name],
      [for (final e in b) e.name],
    );
    expect(a.toSet(), hasLength(a.length));
  });

  test('vacío o sin es/en da vacío', () {
    expect(curateNarratorCatalog([]), isEmpty);
    expect(
      curateNarratorCatalog([
        v('fr-f1', 'fr-FR', VoiceGender.female),
      ]),
      isEmpty,
    );
  });
}
