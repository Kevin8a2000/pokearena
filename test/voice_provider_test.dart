import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/services/narrator_service.dart';
import 'package:pokearena/features/profile/voice_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Narrador - orden de voces (mujeres y español primero)', () {
    test('mujeres en español van primero', () {
      final sorted = sortVoices([
        {'name': 'Microsoft Pablo', 'locale': 'es-ES'},
        {'name': 'Google US English', 'locale': 'en-US'},
        {'name': 'Microsoft Sabina', 'locale': 'es-MX'},
        {'name': 'Google español', 'locale': 'es-ES'},
      ]);
      expect(sorted.first.locale.toLowerCase().startsWith('es'), isTrue);
      expect(sorted.first.gender, VoiceGender.female);
      expect(sorted.last.locale, 'en-US');
    });

    test('detecta nombres femeninos y masculinos típicos', () {
      expect(voiceGender('Microsoft Sabina'), VoiceGender.female);
      expect(voiceGender('Paulina'), VoiceGender.female);
      expect(voiceGender('Google español'), VoiceGender.female);
      expect(voiceGender('Microsoft Pablo'), VoiceGender.male);
      expect(voiceGender('Jorge'), VoiceGender.male);
      expect(voiceGender('Google US English'), VoiceGender.unknown);
    });

    test('nombres crípticos de Google quedan neutros con 🔊', () {
      expect(voiceGender('es-es-x-eea-local'), VoiceGender.unknown);
      const v = NarratorVoice(
        name: 'es-es-x-eea-local',
        locale: 'es-ES',
        gender: VoiceGender.unknown,
      );
      expect(v.label, contains('🔊'));
    });

    test('conserva todas las voces, hombres incluidos', () {
      final sorted = sortVoices([
        {'name': 'Microsoft Pablo', 'locale': 'es-ES'},
        {'name': 'Google US English', 'locale': 'en-US'},
        {'name': 'Microsoft Sabina', 'locale': 'es-MX'},
      ]);
      expect(sorted, hasLength(3));
      expect(
        sorted.any((v) => v.gender == VoiceGender.male),
        isTrue,
      );
      expect(
        sorted.any((v) => v.gender == VoiceGender.female),
        isTrue,
      );
    });

    test('banderas por idioma y región', () {
      expect(flagForLocale('es-ES'), '🇪🇸');
      expect(flagForLocale('es-MX'), '🇲🇽');
      expect(flagForLocale('es-US'), '🇺🇸');
      expect(flagForLocale('en-GB'), '🇬🇧');
      expect(flagForLocale('pt-BR'), '🇧🇷');
      expect(flagForLocale('ar-SA'), '🇸🇦');
      expect(flagForLocale('xx-YY'), '🌐');
    });

    test('alias ficticio estable por voz y género', () {
      final a1 = aliasFor('es-es-x-eea-local', VoiceGender.unknown);
      final a2 = aliasFor('es-es-x-eea-local', VoiceGender.unknown);
      expect(a1, a2);
      expect(
        ['Alex', 'Sam', 'Noa', 'Ari'],
        contains(a1),
      );
      expect(
        ['Lucía', 'Sofía', 'Valentina', 'Camila', 'Martina', 'Isabella'],
        contains(aliasFor('Sabina', VoiceGender.female)),
      );
    });

    test('etiqueta completa con género, bandera, alias e idioma', () {
      const v = NarratorVoice(
        name: 'es-es-x-eea-local',
        locale: 'es-ES',
        gender: VoiceGender.unknown,
      );
      final label = fullVoiceLabel(v);
      expect(label, contains('🔊'));
      expect(label, contains('🇪🇸'));
      expect(label, contains('Español'));
      expect(label, contains('es-ES'));
    });

    test('banderas e idiomas ampliados', () {
      expect(flagForLocale('nl-NL'), '🇳🇱');
      expect(languageName('nl-NL'), 'Neerlandés');
      expect(flagForLocale('ja-JP'), '🇯🇵');
      expect(languageName('ja-JP'), 'Japonés');
      expect(regionName('pt-BR'), 'Brasil');
      expect(regionName('es-CO'), 'Colombia');
      expect(languageName('hi-IN'), 'Hindi');
    });

    test('frase de prueba en el idioma de la voz', () {
      expect(previewPhrase('es-ES'), contains('combate'));
      expect(previewPhrase('en-US'), contains('battle'));
      expect(previewPhrase('pt-BR'), contains('combate'));
      expect(previewPhrase('fr-FR'), contains('combat'));
      expect(previewPhrase('xx-YY'), contains('battle'));
    });

    test('nextGender rota 🔊→♀→♂→🔊', () {
      expect(nextGender(VoiceGender.unknown), VoiceGender.female);
      expect(nextGender(VoiceGender.female), VoiceGender.male);
      expect(nextGender(VoiceGender.male), VoiceGender.unknown);
    });

    test('applyGenderOverrides aplica y reordena', () {
      const base = [
        NarratorVoice(
            name: 'x-male', locale: 'es-ES', gender: VoiceGender.male),
        NarratorVoice(
            name: 'x-crypt', locale: 'es-ES', gender: VoiceGender.unknown),
      ];
      final out = applyGenderOverrides(
        base,
        {'x-crypt': VoiceGender.female},
      );
      expect(out.first.name, 'x-crypt');
      expect(out.first.gender, VoiceGender.female);
    });
  });

  group('VoiceProvider - persistencia de ajustes', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('valores por defecto y cambios con clamp', () async {
      final vp = VoiceProvider();
      expect(vp.enabled, isTrue);
      expect(vp.volume, 0.8);

      await vp.setVolume(2.0);
      expect(vp.volume, 1.0);
      await vp.setVolume(-1.0);
      expect(vp.volume, 0.0);
      await vp.setRate(9.0);
      expect(vp.rate, 1.5);
      await vp.setPitch(0.0);
      expect(vp.pitch, 0.5);
    });

    test('género persiste y se recupera', () async {
      final vp = VoiceProvider();
      expect(vp.gender, VoiceGender.female);
      await vp.setGender(VoiceGender.male);
      expect(vp.gender, VoiceGender.male);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pokearena_voice_gender'), 'male');

      final vp2 = VoiceProvider();
      await vp2.load();
      expect(vp2.gender, VoiceGender.male);
    });

    test('género desconocido cae a hembra', () async {
      final vp = VoiceProvider();
      await vp.setGender(VoiceGender.unknown);
      expect(vp.gender, VoiceGender.female);
    });
  });
}
