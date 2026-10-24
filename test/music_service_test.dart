import 'package:flutter_test/flutter_test.dart';
import 'package:pokearena/core/services/music_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('música persiste el interruptor', () async {
    SharedPreferences.setMockInitialValues({});
    await MusicService.load();
    expect(MusicService.musicOn, isTrue);
    await MusicService.setMusic(false);
    expect(MusicService.musicOn, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('pokearena-music'), isFalse);
    await MusicService.setMusic(true);
    expect(MusicService.musicOn, isTrue);
  });

  test('volumen persiste y se limita a 0..1', () async {
    SharedPreferences.setMockInitialValues({});
    await MusicService.load();
    expect(MusicService.volume, 0.3);
    await MusicService.setVolume(0.8);
    expect(MusicService.volume, 0.8);
    await MusicService.setVolume(2.0);
    expect(MusicService.volume, 1.0);
    await MusicService.setVolume(-1.0);
    expect(MusicService.volume, 0.0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('pokearena-music-vol'), 0.0);
  });

  test('pausa y reanuda no lanzan sin engine', () async {
    SharedPreferences.setMockInitialValues({});
    await MusicService.load();
    await MusicService.pauseBattle();
    await MusicService.resumeBattle();
    expect(MusicService.playing, isFalse);
  });

  test('start sin engine no hace nada ni lanza', () async {
    SharedPreferences.setMockInitialValues({});
    await MusicService.load();
    // En tests (FLUTTER_TEST) el sonido nativo está desactivado.
    await MusicService.start();
    expect(MusicService.playing, isFalse);
    await MusicService.stop();
  });
}
