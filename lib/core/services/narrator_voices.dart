/// Género aparente de la voz. Las voces de Google en Android tienen
/// nombres crípticos (es-es-x-eea-local) sin género identificable:
/// esas quedan como [unknown] con símbolo neutro en vez de adivinar.
enum VoiceGender { female, male, unknown }

/// Voz simple para el selector de voces.
class NarratorVoice {
  final String name;
  final String locale;
  final VoiceGender gender;
  const NarratorVoice({
    required this.name,
    required this.locale,
    required this.gender,
  });

  String get label => fullVoiceLabel(this);

  NarratorVoice copyWith({VoiceGender? gender}) => NarratorVoice(
        name: name,
        locale: locale,
        gender: gender ?? this.gender,
      );

  @override
  bool operator ==(Object other) =>
      other is NarratorVoice &&
      other.name == name &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(name, locale);
}

/// Símbolo del género para la lista.
String genderSymbol(VoiceGender g) => switch (g) {
      VoiceGender.female => '♀',
      VoiceGender.male => '♂',
      VoiceGender.unknown => '🔊',
    };

/// Siguiente género al tocar el icono: 🔊→♀→♂→🔊.
VoiceGender nextGender(VoiceGender g) => switch (g) {
      VoiceGender.unknown => VoiceGender.female,
      VoiceGender.female => VoiceGender.male,
      VoiceGender.male => VoiceGender.unknown,
    };

/// Aplica los géneros marcados por el usuario y reordena.
/// Función pura para poder probarla.
List<NarratorVoice> applyGenderOverrides(
  List<NarratorVoice> base,
  Map<String, VoiceGender> overrides,
) {
  final out = [
    for (final v in base)
      overrides.containsKey(v.name)
          ? v.copyWith(gender: overrides[v.name]!)
          : v,
  ];
  sortNarratorVoices(out);
  return out;
}

/// Frase de prueba en el idioma de la voz (para oírla de verdad).
String previewPhrase(String locale) {
  return switch (locale.split(RegExp('[-_]')).first.toLowerCase()) {
    'es' =>
      '¡Hola! Soy la voz del narrador de PokéArena. ¡Que comience el combate!',
    'en' => 'Hello! I am the PokeArena narrator voice. Let the battle begin!',
    'pt' => 'Olá! Eu sou a voz narradora da PokéArena. Que comece o combate!',
    'fr' =>
      'Bonjour ! Je suis la voix du narrateur PokéArena. Que le combat commence !',
    'de' =>
      'Hallo! Ich bin die Erzählstimme von PokéArena. Der Kampf beginnt!',
    'it' =>
      'Ciao! Sono la voce narrante di PokéArena. Che abbia inizio la battaglia!',
    _ => 'Hello! I am the PokeArena narrator voice. Let the battle begin!',
  };
}

/// Bandera según el idioma/región del locale (`es-ES`→🇪🇸, `es-MX`→🇲🇽…).
String flagForLocale(String locale) {
  final parts = locale.split(RegExp('[-_]'));
  final lang = parts.isNotEmpty ? parts[0].toLowerCase() : '';
  final region = parts.length > 1 ? parts[1].toUpperCase() : '';
  const byRegion = {
    'ES': '🇪🇸',
    'MX': '🇲🇽',
    'US': '🇺🇸',
    'GB': '🇬🇧',
    'BR': '🇧🇷',
    'PT': '🇵🇹',
    'FR': '🇫🇷',
    'DE': '🇩🇪',
    'IT': '🇮🇹',
    'AR': '🇦🇷',
    'CO': '🇨🇴',
    'CL': '🇨🇱',
    'PE': '🇵🇪',
    'VE': '🇻🇪',
    'SA': '🇸🇦',
    'IN': '🇮🇳',
    'JP': '🇯🇵',
    'CN': '🇨🇳',
    'KR': '🇰🇷',
    'RU': '🇷🇺',
  };
  if (byRegion.containsKey(region)) return byRegion[region]!;
  const byLang = {
    'es': '🇪🇸',
    'en': '🇺🇸',
    'pt': '🇧🇷',
    'fr': '🇫🇷',
    'de': '🇩🇪',
    'it': '🇮🇹',
    'ar': '🇸🇦',
    'nl': '🇳🇱',
    'pl': '🇵🇱',
    'tr': '🇹🇷',
    'sv': '🇸🇪',
    'no': '🇳🇴',
    'nb': '🇳🇴',
    'da': '🇩🇰',
    'fi': '🇫🇮',
    'cs': '🇨🇿',
    'sk': '🇸🇰',
    'ro': '🇷🇴',
    'hu': '🇭🇺',
    'el': '🇬🇷',
    'he': '🇮🇱',
    'hi': '🇮🇳',
    'bn': '🇧🇩',
    'ta': '🇮🇳',
    'te': '🇮🇳',
    'mr': '🇮🇳',
    'kn': '🇮🇳',
    'ml': '🇮🇳',
    'gu': '🇮🇳',
    'pa': '🇮🇳',
    'ur': '🇵🇰',
    'fa': '🇮🇷',
    'zh': '🇨🇳',
    'ja': '🇯🇵',
    'ko': '🇰🇷',
    'ru': '🇷🇺',
    'uk': '🇺🇦',
    'id': '🇮🇩',
    'ms': '🇲🇾',
    'vi': '🇻🇳',
    'th': '🇹🇭',
    'sw': '🇰🇪',
    'zu': '🇿🇦',
    'af': '🇿🇦',
  };
  return byLang[lang] ?? '🌐';
}

/// Nombre del idioma en español.
String languageName(String locale) {
  const names = {
    'es': 'Español',
    'en': 'Inglés',
    'pt': 'Portugués',
    'fr': 'Francés',
    'de': 'Alemán',
    'it': 'Italiano',
    'ar': 'Árabe',
    'zh': 'Chino',
    'ja': 'Japonés',
    'ko': 'Coreano',
    'ru': 'Ruso',
    'hi': 'Hindi',
    'nl': 'Neerlandés',
    'pl': 'Polaco',
    'tr': 'Turco',
    'sv': 'Sueco',
    'no': 'Noruego',
    'nb': 'Noruego',
    'da': 'Danés',
    'fi': 'Finlandés',
    'cs': 'Checo',
    'sk': 'Eslovaco',
    'ro': 'Rumano',
    'hu': 'Húngaro',
    'el': 'Griego',
    'he': 'Hebreo',
    'bn': 'Bengalí',
    'ta': 'Tamil',
    'te': 'Télugu',
    'mr': 'Maratí',
    'kn': 'Canarés',
    'ml': 'Malabar',
    'gu': 'Guyaratí',
    'pa': 'Panyabí',
    'ur': 'Urdu',
    'fa': 'Persa',
    'uk': 'Ucraniano',
    'id': 'Indonesio',
    'ms': 'Malayo',
    'vi': 'Vietnamita',
    'th': 'Tailandés',
    'sw': 'Suajili',
    'zu': 'Zulú',
    'af': 'Afrikáans',
  };
  final lang = locale.split(RegExp('[-_]')).first.toLowerCase();
  return names[lang] ?? lang.toUpperCase();
}

/// Nombre del país/región en español.
String regionName(String locale) {
  const names = {
    'ES': 'España',
    'MX': 'México',
    'US': 'EE. UU.',
    'GB': 'Reino Unido',
    'BR': 'Brasil',
    'PT': 'Portugal',
    'FR': 'Francia',
    'DE': 'Alemania',
    'IT': 'Italia',
    'AR': 'Argentina',
    'CO': 'Colombia',
    'CL': 'Chile',
    'PE': 'Perú',
    'VE': 'Venezuela',
    'SA': 'Arabia Saudita',
    'NL': 'Países Bajos',
    'PL': 'Polonia',
    'TR': 'Turquía',
    'SE': 'Suecia',
    'NO': 'Noruega',
    'DK': 'Dinamarca',
    'FI': 'Finlandia',
    'CZ': 'Chequia',
    'RO': 'Rumania',
    'HU': 'Hungría',
    'GR': 'Grecia',
    'IN': 'India',
    'JP': 'Japón',
    'CN': 'China',
    'KR': 'Corea del Sur',
    'RU': 'Rusia',
    'UA': 'Ucrania',
    'ID': 'Indonesia',
  };
  final parts = locale.split(RegExp('[-_]'));
  if (parts.length < 2) return '';
  return names[parts[1].toUpperCase()] ?? parts[1].toUpperCase();
}

/// Variante legible desde nombres crípticos (`es-es-x-eea-local`
/// → `Voz A · local`). Si no hay patrón, `Voz del sistema`.
String variantTag(String name) {
  final lower = name.toLowerCase();
  final match = RegExp(r'x-([a-z]{2,})(?:-|$)').firstMatch(lower);
  final zone = lower.contains('local')
      ? 'local'
      : lower.contains('network')
          ? 'red'
          : '';
  if (match == null) {
    return zone.isEmpty ? 'Voz del sistema' : 'Voz del sistema · $zone';
  }
  final code = match.group(1)!;
  final letter = code.substring(code.length - 1).toUpperCase();
  return zone.isEmpty ? 'Voz $letter' : 'Voz $letter · $zone';
}

const _femaleAliases = [
  'Lucía',
  'Sofía',
  'Valentina',
  'Camila',
  'Martina',
  'Isabella',
];

const _maleAliases = [
  'Mateo',
  'Santiago',
  'Diego',
  'Sebastián',
  'Emilio',
  'Gael',
];

const _neutralAliases = ['Alex', 'Sam', 'Noa', 'Ari'];

/// Hash estable (djb2) para que la misma voz siempre tenga el mismo alias.
int _stableHash(String s) {
  var h = 5381;
  for (final c in s.codeUnits) {
    h = ((h << 5) + h + c) & 0x7fffffff;
  }
  return h;
}

/// Alias ficticio para identificar la voz (no cambia la voz real).
String aliasFor(String voiceName, VoiceGender gender) {
  final pool = switch (gender) {
    VoiceGender.female => _femaleAliases,
    VoiceGender.male => _maleAliases,
    VoiceGender.unknown => _neutralAliases,
  };
  return pool[_stableHash(voiceName) % pool.length];
}

/// Etiqueta completa: género + bandera + alias + idioma + variante.
/// Ej: `♀ 🇪🇸 Lucía · Español (España) · Voz A · local (es-ES)`.
String fullVoiceLabel(NarratorVoice v) {
  final lang = languageName(v.locale);
  final region = regionName(v.locale);
  final where = region.isEmpty ? lang : '$lang ($region)';
  return '${genderSymbol(v.gender)} ${flagForLocale(v.locale)} ${aliasFor(v.name, v.gender)} · $where · ${variantTag(v.name)} (${v.locale})';
}

/// Nombres típicos de voces femeninas en español (Windows, Google, Apple).
const _femaleHints = [
  'female',
  'mujer',
  'sabina',
  'helena',
  'laura',
  'lucia',
  'paulina',
  'monica',
  'marisol',
  'sofia',
  'camila',
  'valentina',
  'carmen',
  'maria',
  'ana',
  'elena',
  'isabel',
  'eva',
  'rosa',
  'google español',
];

bool isFemaleVoice(String name) =>
    voiceGender(name) == VoiceGender.female;

/// Nombres típicos masculinos para no marcarlos como desconocidos.
const _maleHints = [
  'male',
  'hombre',
  'pablo',
  'jorge',
  'diego',
  'enrique',
  'raul',
  'raúl',
  'miguel',
  'carlos',
  'juan',
  'pedro',
  'antonio',
  'david',
  'javier',
];

VoiceGender voiceGender(String name) {
  final lower = name.toLowerCase();
  if (_femaleHints.any(lower.contains)) return VoiceGender.female;
  if (_maleHints.any(lower.contains)) return VoiceGender.male;
  return VoiceGender.unknown;
}

/// Catálogo curado para Ajustes: solo inglés y español, hasta 3 voces
/// por género (hembra/macho) e idioma. Si un grupo trae menos de 3 con
/// género detectado, se rellena con las sin género (neutras).
/// Máximo 12, determinista (alfabético) y reordenado al final.
/// Función pura para poder probarla.
List<NarratorVoice> curateNarratorCatalog(
  List<NarratorVoice> voices, {
  int perGroup = 3,
}) {
  String langOf(NarratorVoice v) =>
      v.locale.split(RegExp('[-_]')).first.toLowerCase();
  final used = <NarratorVoice>{};
  final out = <NarratorVoice>[];
  for (final lang in ['es', 'en']) {
    final group = voices.where((v) => langOf(v) == lang).toList();
    for (final gender in [VoiceGender.female, VoiceGender.male]) {
      final named = group.where((v) => v.gender == gender).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      final picked = named.take(perGroup).toList();
      if (picked.length < perGroup) {
        final fillers = group
            .where((v) =>
                v.gender == VoiceGender.unknown &&
                !picked.contains(v) &&
                !used.contains(v))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        picked.addAll(fillers.take(perGroup - picked.length));
      }
      used.addAll(picked);
      out.addAll(picked);
    }
  }
  sortNarratorVoices(out);
  return out;
}

/// Ordena: español primero; luego ♀, 🔊 y ♂; alfabético al final.
/// No filtra nada: aparecen todas las voces del dispositivo.
void sortNarratorVoices(List<NarratorVoice> voices) {
  int rank(VoiceGender g) => switch (g) {
        VoiceGender.female => 0,
        VoiceGender.unknown => 1,
        VoiceGender.male => 2,
      };
  voices.sort((a, b) {
    final aEs = a.locale.toLowerCase().startsWith('es') ? 0 : 1;
    final bEs = b.locale.toLowerCase().startsWith('es') ? 0 : 1;
    if (aEs != bEs) return aEs - bEs;
    final r = rank(a.gender) - rank(b.gender);
    if (r != 0) return r;
    return a.name.compareTo(b.name);
  });
}

/// Convierte la lista cruda del plugin y la ordena.
/// Función pura para poder probarla sin el plugin.
List<NarratorVoice> sortVoices(List<Map<String, String>> raw) {
  final voices = [
    for (final v in raw)
      NarratorVoice(
        name: v['name'] ?? 'Voz',
        locale: v['locale'] ?? '',
        gender: voiceGender(v['name'] ?? ''),
      ),
  ];
  sortNarratorVoices(voices);
  return voices;
}
