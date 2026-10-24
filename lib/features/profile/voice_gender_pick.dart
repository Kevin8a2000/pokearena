import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/narrator_voices.dart';
import '../../core/theme/poke_design.dart';
import '../../core/widgets/poke_widgets.dart';
import 'voice_provider.dart';

/// Selector de género del narrador (♀ Mujer / ♂ Hombre) + probar voz.
/// Compartido entre Perfil y Ajustes. Radios Pokébola y botón ▶ rojo.
class VoiceGenderPick extends StatelessWidget {
  const VoiceGenderPick({super.key});

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VoiceProvider>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PokeRadio<VoiceGender>(
          value: VoiceGender.female,
          groupValue: vp.gender,
          onChanged: vp.setGender,
          label: Text('♀ Mujer', style: pokeText(18)),
        ),
        PokeRadio<VoiceGender>(
          value: VoiceGender.male,
          groupValue: vp.gender,
          onChanged: vp.setGender,
          label: Text('♂ Hombre', style: pokeText(18)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            PokeRoundButton(icon: Icons.play_arrow, onPressed: vp.preview, size: 48, tooltip: 'Probar voz'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Probar voz', style: pokeText(18)),
                  Text(
                    vp.current == null ? 'Sin voz en este dispositivo' : fullVoiceLabel(vp.current!),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
