import 'dart:io';

/// En `flutter test` (FLUTTER_TEST=true) no hay plugin audioplayers:
/// el sonido nativo se desactiva para no romper los tests.
bool get disableNativeSound =>
    Platform.environment.containsKey('FLUTTER_TEST');
