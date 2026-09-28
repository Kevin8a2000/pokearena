import 'pokemon.dart';

/// Nodo de la cadena evolutiva. Es un árbol porque hay evoluciones que se
/// ramifican (por ejemplo Eevee tiene varias evoluciones).
class EvolutionNode {
  final int id;
  final String name;
  final List<EvolutionNode> children;

  const EvolutionNode({
    required this.id,
    required this.name,
    this.children = const [],
  });

  /// Lee el objeto "chain" de /evolution-chain/{id}.
  factory EvolutionNode.fromChainJson(Map<String, dynamic> json) {
    final species = json['species'] as Map<String, dynamic>;
    return EvolutionNode(
      id: idFromUrl(species['url'] as String),
      name: species['name'] as String,
      children: [
        for (final next in (json['evolves_to'] as List? ?? const []))
          EvolutionNode.fromChainJson(next as Map<String, dynamic>),
      ],
    );
  }

  // Formato propio y compacto para guardarlo en el caché.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'children': [for (final c in children) c.toJson()],
      };

  factory EvolutionNode.fromJson(Map<String, dynamic> json) => EvolutionNode(
        id: json['id'] as int,
        name: json['name'] as String,
        children: [
          for (final c in (json['children'] as List))
            EvolutionNode.fromJson(c as Map<String, dynamic>),
        ],
      );
}
