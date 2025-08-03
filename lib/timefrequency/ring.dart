import 'package:flutter/widgets.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../config.dart';

class Ring {
  ValueNotifier<bool?> isRinging;
  Ring(this.isRinging);
  bool? alreadyInit;
  AudioSource? toneSource;
  SoundHandle? handle;
  Future<void> start(double frequency) async {
    bool isPlaying = (isRinging.value == true);
    isRinging.value = null;
    alreadyInit ??= await Config.initSoLoud();
    toneSource ??= await SoLoud.instance.loadWaveform(
      WaveForm.sin,
      false,
      1.0,
      0.0,
    );
    SoLoud.instance.setWaveformFreq(toneSource!, frequency);
    if (!isPlaying) {
      handle = await SoLoud.instance.play(toneSource!);
    }
    isRinging.value = true;
  }

  Future<void> stop() async {
    isRinging.value = null;
    if (handle != null) {
      const Duration fadeDuration = Duration(milliseconds: 100);
      SoLoud.instance.fadeVolume(handle!, 0.0, fadeDuration);
      await Future.delayed(fadeDuration);
      await SoLoud.instance.stop(handle!);
      handle = null;
    }
    isRinging.value = false;
  }

  void dispose() async {
    if (alreadyInit == false) {
      SoLoud.instance.deinit();
    } else if (alreadyInit == true) {
      if (handle != null) await SoLoud.instance.stop(handle!);
      if (toneSource != null) {
        SoLoud.instance.disposeSource(toneSource!);
        toneSource = null;
      }
    }
  }
}
