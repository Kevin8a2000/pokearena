import 'package:flutter/material.dart';

enum TermsKind { privacy, terms }

/// Textos legales de fachada (proyecto de clase, sin validez real).
class TermsPage extends StatelessWidget {
  final TermsKind kind;
  const TermsPage({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final isPrivacy = kind == TermsKind.privacy;
    return Scaffold(
      appBar: AppBar(
        title: Text(isPrivacy
            ? 'Política de privacidad'
            : 'Términos y condiciones'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            isPrivacy
                ? _privacyText
                : _termsText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const Text(
            'Documento de fachada para proyecto académico. '
            'Sin validez legal.',
            style: TextStyle(
                fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

const _privacyText = '''
POLÍTICA DE PRIVACIDAD DE POKÉARENA (FACHADA)

1. Datos que guardamos
Guardamos en tu propio teléfono: tu usuario, tu equipo Pokémon,
tus favoritos, tu historial de puntajes y tus ajustes (fondo,
sonido y avatar). Nada sale de tu dispositivo salvo lo necesario
para jugar en línea (salas y combates del Duelo online).

2. Duelo online
Al crear o unirte a una sala compartimos con tu rival tu nombre
de entrenador, tu luchador y tus controles durante el duelo. Los datos
de la sala solo se usan mientras dura la partida.

3. Menores de edad
PokéArena es un proyecto de clase. Si tienes menos de 13 años,
juega con supervisión de un adulto.

4. Tus derechos
Puedes borrar tus datos desde Perfil (vaciar equipo y favoritos)
o desinstalando la app, lo que elimina todo lo guardado.
''';

const _termsText = '''
TÉRMINOS Y CONDICIONES DE POKÉARENA (FACHADA)

1. El juego
PokéArena es un proyecto académico sin fines comerciales. Los
datos de Pokémon provienen de PokeAPI y los sprites de sus
fuentes abiertas con fines educativos.

2. Uso aceptable
No hagas trampa en el modo online, no insultes a tu rival y no
intentes dañar las salas de otros jugadores. El incumplimiento
puede llevar a la expulsión de la sala.

3. Disponibilidad
El modo online depende de tu conexión a internet. Sin conexión,
los modos locales (Pokédex, Equipo, Batalla, Quiz) siguen
funcionando con normalidad.

4. Cambios
Estas condiciones de fachada pueden cambiar con cada entrega
del proyecto. Al seguir jugando aceptas la versión vigente.
''';
