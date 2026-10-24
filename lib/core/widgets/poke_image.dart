import 'package:flutter/material.dart';

/// Tipo de sprite: arte oficial HD, pixel Gen 5 (frente/espalda)
/// o GIF animado Gen 5 (frente/espalda, ids 1-649 con caída a PNG).
enum PokeSpriteKind { artwork, front, back, animatedFront, animatedBack }

/// URLs candidatas para el sprite (en orden de intento).
/// Si raw.githubusercontent falla en el navegador (statusCode 0 por
/// saturación/CORS), se cae a jsDelivr. Los pixel Gen 5 caen al arte
/// oficial para que siempre se vea algo.
List<String> spriteCandidates(int id,
    [PokeSpriteKind kind = PokeSpriteKind.artwork]) {
  const raw = 'https://raw.githubusercontent.com/PokeAPI/sprites/master';
  const jsd = 'https://cdn.jsdelivr.net/gh/PokeAPI/sprites@master';
  final art = 'sprites/pokemon/other/official-artwork/$id.png';
  final front = 'sprites/pokemon/$id.png';
  final back = 'sprites/pokemon/back/$id.png';
  // GIF animados Gen 5 (1-649). Si el id no tiene GIF, el errorBuilder
  // de PokeImage pasa al siguiente CDN / PNG estático automáticamente.
  final animFront =
      'sprites/pokemon/versions/generation-v/black-white/animated/$id.gif';
  final animBack =
      'sprites/pokemon/versions/generation-v/black-white/animated/back/$id.gif';
  return switch (kind) {
    PokeSpriteKind.animatedFront => [
        '$raw/$animFront',
        '$jsd/$animFront',
        '$raw/$front',
        '$jsd/$front',
        '$raw/$art',
        '$jsd/$art',
      ],
    PokeSpriteKind.animatedBack => [
        '$raw/$animBack',
        '$jsd/$animBack',
        '$raw/$back',
        '$jsd/$back',
        '$raw/$front',
        '$jsd/$front',
        '$raw/$art',
        '$jsd/$art',
      ],
    PokeSpriteKind.artwork => [
        '$raw/$art',
        '$jsd/$art',
        '$raw/$front',
        '$jsd/$front',
      ],
    PokeSpriteKind.front => [
        '$raw/$front',
        '$jsd/$front',
        '$raw/$art',
        '$jsd/$art',
      ],
    PokeSpriteKind.back => [
        '$raw/$back',
        '$jsd/$back',
        '$raw/$front',
        '$jsd/$front',
        '$raw/$art',
      ],
  };
}

/// Máximo id con avatar de perfil guardado en la app (sin internet).
/// Ver `assets/images/avatars/` — arte oficial 160x160, #1 a #120.
const int kLocalAvatarMaxId = 120;

String _localAvatarAsset(int id) => 'assets/images/avatars/$id.png';

/// Imagen de Pokémon resistente: spinner mientras carga, prueba el
/// siguiente CDN si falla y muestra icono + reintento al agotarlos.
/// [cacheWidth] decodifica más chico en grillas (más rápido, menos memoria).
class PokeImage extends StatefulWidget {
  final int id;
  final PokeSpriteKind kind;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;
  final Color placeholderColor;
  final double iconSize;

  /// Calidad del escalado (alta para sprites grandes en pantalla).
  final FilterQuality filterQuality;

  /// Si es `true` y [id] <= [kLocalAvatarMaxId], usa el PNG guardado en
  /// `assets/images/avatars/` en vez de pedirlo por internet (funciona sin
  /// conexión). Solo lo usa el selector de foto de perfil: el resto de la
  /// app (Pokédex, equipo, batalla) sigue igual que siempre.
  final bool preferLocalAvatar;

  const PokeImage({
    super.key,
    required this.id,
    this.kind = PokeSpriteKind.artwork,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.cacheWidth,
    this.placeholderColor = Colors.white,
    this.iconSize = 32,
    this.filterQuality = FilterQuality.low,
    this.preferLocalAvatar = false,
  });

  @override
  State<PokeImage> createState() => _PokeImageState();
}

class _PokeImageState extends State<PokeImage> {
  int _idx = 0;
  int _retry = 0;

  @override
  void didUpdateWidget(PokeImage old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id || old.kind != widget.kind) {
      _idx = 0;
      _retry = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.preferLocalAvatar && widget.id <= kLocalAvatarMaxId && widget.id >= 1) {
      return Image.asset(
        _localAvatarAsset(widget.id),
        key: ValueKey('local-avatar-${widget.id}'),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        filterQuality: widget.filterQuality,
        gaplessPlayback: true,
      );
    }
    final urls = spriteCandidates(widget.id, widget.kind);
    if (_idx >= urls.length) {
      // Sin imagen: icono + toque para reintentar desde el primer CDN.
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: IconButton(
          tooltip: 'Reintentar imagen',
          icon: Icon(Icons.refresh,
              size: widget.iconSize, color: widget.placeholderColor),
          onPressed: () => setState(() {
            _idx = 0;
            _retry++;
          }),
        ),
      );
    }
    return Image.network(
      urls[_idx],
      key: ValueKey('${widget.kind.name}-${widget.id}-$_idx-$_retry'),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      filterQuality: widget.filterQuality,
      gaplessPlayback: true,
      loadingBuilder: (c, child, prog) => prog == null
          ? child
          : SizedBox(
              width: widget.width,
              height: widget.height,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.placeholderColor,
                  ),
                ),
              ),
            ),
      errorBuilder: (c, e, s) {
        // Pasa al siguiente CDN en el próximo frame.
        Future.microtask(() {
          if (mounted) setState(() => _idx++);
        });
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.placeholderColor,
              ),
            ),
          ),
        );
      },
    );
  }
}
