import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/pokemon.dart';
import '../../core/models/type_relations.dart';
import '../../core/services/pokeapi_service.dart';
import '../../core/theme/poke_design.dart';
import '../../core/theme/type_colors.dart';
import '../../core/widgets/mode_illustrations.dart';
import '../../core/widgets/poke_image.dart';
import '../../core/widgets/poke_widgets.dart';
import '../auth/auth_provider.dart';
import '../battle/battle_terrain.dart';
import '../duel/duel_screen.dart';
import '../duel/net/duel_link.dart';
import '../duel/net/duel_transport.dart';
import '../team/team_provider.dart';
import 'online_room.dart';

/// Lobby del Duelo online: crea una sala (código de 6) o únete con el código
/// de tu rival. Ambos eligen su luchador; cuando los dos están, empieza el
/// duelo en tiempo real.
class OnlineLobbyScreen extends StatefulWidget {
  /// Base de datos (inyectable en pruebas).
  final FirebaseFirestore? db;
  const OnlineLobbyScreen({super.key, this.db});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  OnlineRoom? _room;
  StreamSubscription? _sub;
  bool _navigated = false;
  PokemonDetail? _mine;

  bool _nameInit = false;

  FirebaseFirestore get _db => widget.db ?? FirebaseFirestore.instance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nameInit) {
      _nameInit = true;
      _name.text = Provider.of<AuthProvider>(context, listen: false).currentUser ?? '';
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  List<PokemonDetail> get _team => context.read<TeamProvider>().team.toList();

  String get _displayName => _name.text.trim().isEmpty ? 'Entrenador' : _name.text.trim();

  /// Luchador elegido (por defecto, el primero del equipo).
  PokemonDetail? get _fighter {
    final team = _team;
    if (team.isEmpty) return null;
    final m = _mine;
    if (m != null && team.any((p) => p.id == m.id)) return m;
    return team.first;
  }

  Future<void> _create() async {
    final fighter = _fighter;
    if (fighter == null) {
      setState(() => _error = 'Arma tu equipo primero (pestaña Equipo).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final room = await OnlineRoom.create(
        _db,
        name: _displayName,
        fighter: fighter,
        seed: Random().nextInt(1 << 31),
      );
      _room = room;
      // Espero al rival: cuando se una, marco la sala lista y entro.
      _sub = room.watch().listen((snap) {
        final players = (snap.data()?['players'] as Map?) ?? {};
        if (players.containsKey('p1')) {
          room.markReady();
          _enterDuel(room);
        }
      });
      setState(() => _busy = false);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Sin conexión. Revisa tu internet e intenta de nuevo.';
      });
    }
  }

  Future<void> _join() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'El código tiene 6 letras/números.');
      return;
    }
    final fighter = _fighter;
    if (fighter == null) {
      setState(() => _error = 'Arma tu equipo primero (pestaña Equipo).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final room = await OnlineRoom.join(_db, code: code, name: _displayName, fighter: fighter);
      _room = room;
      _sub = room.watch().listen((snap) {
        if (snap.data()?['status'] == 'ready') _enterDuel(room);
      });
      setState(() => _busy = false);
    } on OnlineRoomError catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Sin conexión. Revisa tu internet e intenta de nuevo.';
      });
    }
  }

  /// Relaciones de tipo de los dos luchadores (sin red quedan neutras).
  Future<Map<String, TypeRelations>> _relationsFor(PokemonDetail a, PokemonDetail b) async {
    final out = <String, TypeRelations>{};
    PokeApiService? api;
    try {
      api = context.read<PokeApiService>();
    } catch (_) {}
    if (api == null) return out;
    await Future.wait([
      for (final t in {...a.types, ...b.types})
        api.fetchTypeRelations(t).then((r) => out[t.toLowerCase()] = r).catchError((_) => const TypeRelations(typeName: '')),
    ]);
    out.removeWhere((_, r) => r.typeName.isEmpty);
    return out;
  }

  void _enterDuel(OnlineRoom room) async {
    if (_navigated || !mounted) return;
    _navigated = true;
    _sub?.cancel();
    try {
      final state = await room.fetchState();
      final players = (state?['players'] as Map?) ?? {};
      final p0 = players['p0'] as Map?;
      final p1 = players['p1'] as Map?;
      if (p0 == null || p1 == null || !mounted) {
        setState(() {
          _navigated = false;
          _error = 'La sala se cerró. Intenta de nuevo.';
        });
        return;
      }
      final seed = (state?['seed'] as num?)?.toInt() ?? 1;
      final hostMon = fighterFromJson(p0['fighter'] as Map);
      final guestMon = fighterFromJson(p1['fighter'] as Map);
      final relations = await _relationsFor(hostMon, guestMon);
      if (!mounted) return;
      // Terreno determinista por la semilla de la sala: los dos ven el mismo.
      final terrains = battleTerrains.where((t) => t.forHorde).toList();
      final terrain = terrains[seed % terrains.length];
      final transport = FirestoreDuelTransport(_db, room.code);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DuelScreen(
            hostFighter: hostMon,
            guestFighter: guestMon,
            hostName: (p0['name'] ?? 'Anfitrión') as String,
            guestName: (p1['name'] ?? 'Invitado') as String,
            terrain: terrain,
            relations: relations,
            host: room.isHost ? DuelHostLink(transport) : null,
            guest: room.isHost ? null : DuelGuestLink(transport),
            onFinish: room.isHost ? (winner, reason) => room.claimResult(winner: winner, reason: reason) : null,
            onLeave: (fighting) => room.leave(wasFighting: fighting),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _navigated = false;
        _error = 'Sin conexión. Intenta de nuevo.';
      });
    }
  }

  Future<void> _cancel() async {
    await _room?.leave(wasFighting: false);
    _sub?.cancel();
    if (mounted) Navigator.pop(context);
  }

  /// Campo de texto crema con borde negro (diseño "colores Pokémon").
  InputDecoration _field(String label, {IconData? icon, String? hint}) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, color: PokeColors.ink),
      filled: true,
      fillColor: PokeColors.cream,
      counterText: '',
      labelStyle: const TextStyle(color: PokeColors.ink, fontWeight: FontWeight.w700),
      floatingLabelStyle: const TextStyle(color: PokeColors.goldLight, fontWeight: FontWeight.w800, backgroundColor: PokeColors.navyPanel),
      border: border(Colors.black, 2.5),
      enabledBorder: border(Colors.black, 2.5),
      focusedBorder: border(PokeColors.gold, 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _room != null;
    final team = context.watch<TeamProvider>().team;
    final fighter = _fighter;
    const textStyle = TextStyle(color: PokeColors.ink, fontWeight: FontWeight.w800, fontSize: 16);
    return PokeScaffold(
      title: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [PokeBackButton(), SizedBox(width: 14), PokeLogoText('Duelo Online', size: 34)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            shrinkWrap: true,
            children: [
              const Center(child: OnlineIllustration(width: 120)),
              const SizedBox(height: 8),
              Text('Rival en línea', textAlign: TextAlign.center, style: pokeText(30, shadows: pokeTextShadow)),
              const SizedBox(height: 4),
              const Text(
                'Uno crea la sala y comparte el código. El otro se une con ese código. Pelean en tiempo real, al mejor de 3 rondas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, shadows: pokeTextShadow),
              ),
              const SizedBox(height: 16),
              if (!waiting) ...[
                TextField(
                  controller: _name,
                  maxLength: 16,
                  style: textStyle,
                  decoration: _field('Tu nombre', icon: Icons.person),
                ),
                const SizedBox(height: 14),
                PokePanel(
                  color: const Color(0xFF2B57A6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tu luchador', style: pokeText(21)),
                      const SizedBox(height: 8),
                      if (team.isEmpty)
                        const Text('Arma tu equipo en la pestaña Equipo para poder pelear.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white))
                      else
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final p in team.take(6))
                              _FighterChip(
                                pokemon: p,
                                selected: fighter?.id == p.id,
                                onTap: () => setState(() => _mine = p),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PokeButton(expanded: true, height: 58, fontSize: 22, icon: Icons.add, label: 'CREAR SALA', onPressed: _busy ? null : _create),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _code,
                        maxLength: 6,
                        textCapitalization: TextCapitalization.characters,
                        style: textStyle.copyWith(letterSpacing: 3),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                        ],
                        decoration: _field('Código', hint: 'AB12CD'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    PokeButton(
                      height: 56,
                      fontSize: 18,
                      icon: Icons.login,
                      label: 'UNIRSE',
                      color: PokeColors.blue,
                      darkColor: PokeColors.navyDark,
                      onPressed: _busy ? null : _join,
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  _room!.isHost ? 'Comparte este código con tu rival:' : 'Te uniste a la sala:',
                  textAlign: TextAlign.center,
                  style: pokeText(19),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Clipboard.setData(ClipboardData(text: _room!.code)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      color: PokeColors.cream,
                      border: Border.all(color: PokeColors.gold, width: 4),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_room!.code, textAlign: TextAlign.center, style: pokeText(52, color: PokeColors.ink).copyWith(letterSpacing: 8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: PokeColors.goldLight)),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _room!.isHost ? 'Esperando al rival… (toca el código para copiar)' : 'Esperando a que el anfitrión empiece…',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, shadows: pokeTextShadow),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(child: PokeButton(label: 'Cancelar', color: const Color(0xFF5A6A99), darkColor: const Color(0xFF2A3560), onPressed: _cancel)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: PokeColors.red.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12), border: Border.all(color: PokeColors.red, width: 2)),
                  child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Luchador elegible: tarjeta del color de su tipo; el elegido lleva borde blanco.
class _FighterChip extends StatelessWidget {
  final PokemonDetail pokemon;
  final bool selected;
  final VoidCallback onTap;
  const _FighterChip({required this.pokemon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final base = colorForType(pokemon.types.isEmpty ? 'normal' : pokemon.types.first);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(base, Colors.white, 0.25)!, base]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Colors.white : Colors.black, width: selected ? 3.5 : 2.5),
          boxShadow: [BoxShadow(color: selected ? Colors.white54 : Colors.black45, blurRadius: selected ? 8 : 3, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PokeImage(id: pokemon.id, kind: PokeSpriteKind.front, width: 56, height: 56, cacheWidth: 112),
            FittedBox(fit: BoxFit.scaleDown, child: Text(prettyName(pokemon.name), maxLines: 1, style: pokeText(15, shadows: pokeTextShadow))),
          ],
        ),
      ),
    );
  }
}
