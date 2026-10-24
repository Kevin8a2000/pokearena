import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/services/cry_service.dart';

void main() {
  test('candidatos incluyen el id y el formato ogg', () {
    final urls = cryCandidates(25);
    expect(urls, isNotEmpty);
    expect(urls.every((u) => u.contains('25.ogg')), isTrue);
    expect(urls.first, contains('latest'));
  });

  test('legacy solo para ids 1-649', () {
    expect(cryCandidates(25).any((u) => u.contains('legacy')), isTrue);
    expect(cryCandidates(700).any((u) => u.contains('legacy')), isFalse);
  });

  test('asset local solo Gen 1 (1-151)', () {
    expect(isLocalCry(1), isTrue);
    expect(isLocalCry(151), isTrue);
    expect(isLocalCry(152), isFalse);
    expect(isLocalCry(1025), isFalse);
  });
}
