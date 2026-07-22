// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Quasar.io — Interstellar tarzı epik uzay teması.
/// Organ, yaylılar, koro pad, piyano. WAV üretir, ffmpeg ile MP3'ye çevirir.
Future<void> main() async {
  const sampleRate = 44100;
  const durationSec = 40.0;
  const wavPath = 'assets/audio/_temp_theme.wav';
  const mp3Path = 'assets/audio/quasar_orbit_theme.mp3';

  final n = (sampleRate * durationSec).round();
  final buf = Float64List(n);

  const chords = [
    [49.0, 58.27, 73.42], // Gm
    [43.65, 55.0, 65.41], // Eb
    [46.25, 58.27, 69.30], // Bb
    [41.20, 49.0, 61.74], // F
    [43.65, 55.0, 65.41], // Eb
    [49.0, 58.27, 73.42], // Gm
    [46.25, 55.0, 69.30], // Bb/D
    [49.0, 58.27, 73.42], // Gm
  ];
  const chordDur = durationSec / 8;

  const melody = [
    (3.0, 392.0, 6.0),
    (10.0, 311.13, 5.5),
    (16.5, 293.66, 5.0),
    (22.0, 233.08, 5.5),
    (28.0, 261.63, 5.0),
    (34.0, 311.13, 5.5),
  ];

  const piano = [
    (2.0, 196.0), (4.5, 233.08), (7.0, 261.63), (9.5, 293.66),
    (12.0, 261.63), (14.5, 233.08), (17.0, 196.0), (19.5, 233.08),
    (22.0, 261.63), (24.5, 293.66), (27.0, 311.13), (29.5, 293.66),
    (32.0, 261.63), (34.5, 233.08), (37.0, 196.0),
  ];

  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    var s = 0.0;

    final chordIdx = (t / chordDur).floor().clamp(0, chords.length - 1);
    final nextIdx = (chordIdx + 1) % chords.length;
    final localT = t % chordDur;
    final blend = _smoothStep(localT / chordDur);
    final env = _softFade(localT, chordDur, 4.0, 4.0);

    final chord = chords[chordIdx];
    final nextChord = chords[nextIdx];

    // Pedal G — sürekli derinlik.
    s += _organ(49.0, t) * 0.085;
    s += _organ(49.0 * 2, t + 0.3) * 0.03;

    for (var v = 0; v < 3; v++) {
      final freq = chord[v] + (nextChord[v] - chord[v]) * blend;
      s += _organ(freq, t + v * 0.2) * env * (0.085 - v * 0.018);
      s += _organ(freq * 2, t + v * 0.35) * env * 0.028;
      s += _strings(freq * 2, t + v * 0.5) * env * 0.05;
      s += _strings(freq * 3, t + v * 0.7) * env * 0.028;
      s += _choir(freq * 4, t + v * 0.4) * env * 0.022;
    }

    for (final (start, freq, dur) in melody) {
      final noteT = t - start;
      if (noteT < 0 || noteT > dur + 3.0) continue;
      final noteEnv = _softFade(noteT, dur, 2.0, 3.0);
      s += _organ(freq, t) * noteEnv * 0.065;
      s += _strings(freq, t + 0.15) * noteEnv * 0.05;
    }

    for (final (start, freq) in piano) {
      final noteT = t - start;
      if (noteT < 0 || noteT > 3.5) continue;
      final noteEnv = math.exp(-noteT * 2.2);
      s += _piano(freq * 2, t) * noteEnv * 0.035;
    }

    final swell = 0.7 + 0.3 * math.sin(2 * math.pi * t / durationSec - 0.5);
    final breath = 0.85 + 0.15 * math.sin(2 * math.pi * t / 20.0);
    buf[i] = s * swell * breath;
  }

  _applyLowPass(buf, 5);
  _applyReverb(buf, sampleRate, [2600, 3400, 4300, 5500], [0.36, 0.3, 0.24, 0.17]);
  _normalize(buf, 0.7);
  _crossfadeLoop(buf, sampleRate ~/ 35);

  final pcm = Int16List(n);
  for (var i = 0; i < n; i++) {
    pcm[i] = (buf[i].clamp(-1.0, 1.0) * 28000).round();
  }

  _writeWav(wavPath, pcm, sampleRate);
  print('Wrote $wavPath (${File(wavPath).lengthSync()} bytes)');

  final ffmpeg = await _findFfmpeg();
  if (ffmpeg == null) {
    print('ffmpeg bulunamadı — MP3 dönüşümü atlandı.');
    exit(1);
  }

  final result = await Process.run(ffmpeg, [
    '-y',
    '-i', wavPath,
    '-codec:a', 'libmp3lame',
    '-b:a', '192k',
    '-ar', '44100',
    mp3Path,
  ]);

  if (result.exitCode != 0) {
    print('ffmpeg hatası: ${result.stderr}');
    exit(1);
  }

  await File(wavPath).delete();
  final oldWav = File('assets/audio/quasar_orbit_theme.wav');
  if (oldWav.existsSync()) await oldWav.delete();

  print('Wrote $mp3Path (${File(mp3Path).lengthSync()} bytes, ${durationSec}s)');
}

Future<String?> _findFfmpeg() async {
  const candidates = ['ffmpeg', 'ffmpeg.exe'];
  for (final cmd in candidates) {
    final result = await Process.run(
      Platform.isWindows ? 'where' : 'which',
      [cmd],
      runInShell: true,
    );
    if (result.exitCode == 0) {
      final path = result.stdout.toString().trim().split('\n').first.trim();
      if (path.isNotEmpty) return path;
    }
  }

  final projectFfmpeg = Directory('tool/ffmpeg');
  if (projectFfmpeg.existsSync()) {
    for (final entry in projectFfmpeg.listSync(recursive: true)) {
      if (entry is File && entry.path.endsWith('ffmpeg.exe')) {
        return entry.path;
      }
    }
  }

  if (Platform.isWindows) {
    final local = Platform.environment['LOCALAPPDATA'];
    if (local != null) {
      final wingetDir = Directory('$local/Microsoft/WinGet/Packages');
      if (wingetDir.existsSync()) {
        for (final entry in wingetDir.listSync()) {
          if (entry is! Directory) continue;
          if (!entry.path.contains('FFmpeg')) continue;
          for (final bin in entry.listSync(recursive: true)) {
            if (bin is File && bin.path.endsWith('ffmpeg.exe')) {
              return bin.path;
            }
          }
        }
      }
    }
  }
  return null;
}

double _organ(double freq, double t) {
  final p = 2 * math.pi * freq * t;
  return math.sin(p) * 0.42 +
      math.sin(p * 2) * 0.24 +
      math.sin(p * 3) * 0.15 +
      math.sin(p * 4) * 0.09 +
      math.sin(p * 6) * 0.05 +
      math.sin(p * 8) * 0.03 +
      math.sin(p * 16) * 0.02;
}

double _strings(double freq, double t) {
  final vib = 1.0 + 0.0035 * math.sin(2 * math.pi * 4.5 * t);
  final p = 2 * math.pi * freq * vib * t;
  return math.sin(p) * 0.52 +
      math.sin(p * 2) * 0.26 +
      math.sin(p * 3) * 0.13 +
      math.sin(p * 4) * 0.06 +
      math.sin(p * 5) * 0.03;
}

double _choir(double freq, double t) {
  final p = 2 * math.pi * freq * t;
  return math.sin(p) * 0.6 +
      math.sin(p * 2 + 0.3) * 0.2 +
      math.sin(p * 3 + 0.6) * 0.12 +
      math.sin(p * 4 + 0.9) * 0.08;
}

double _piano(double freq, double t) {
  final p = 2 * math.pi * freq * t;
  return math.sin(p) * 0.55 +
      math.sin(p * 2) * 0.22 +
      math.sin(p * 3) * 0.12 +
      math.sin(p * 4) * 0.06 +
      math.sin(p * 5) * 0.04;
}

double _smoothStep(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

double _softFade(double t, double dur, double fadeIn, double fadeOut) {
  final fi = fadeIn <= 0 ? 1.0 : (t / fadeIn).clamp(0.0, 1.0);
  final remain = dur - t;
  final fo = fadeOut <= 0 ? 1.0 : (remain / fadeOut).clamp(0.0, 1.0);
  return fi * fo;
}

void _applyLowPass(Float64List buf, int radius) {
  final tmp = Float64List.fromList(buf);
  for (var i = 0; i < buf.length; i++) {
    var sum = 0.0;
    var count = 0;
    for (var k = -radius; k <= radius; k++) {
      final idx = i + k;
      if (idx < 0 || idx >= buf.length) continue;
      sum += tmp[idx];
      count++;
    }
    buf[i] = sum / count;
  }
}

void _applyReverb(
  Float64List buf,
  int sampleRate,
  List<int> delaysMs,
  List<double> gains,
) {
  for (var d = 0; d < delaysMs.length; d++) {
    final delaySamples = (delaysMs[d] * sampleRate / 1000).round();
    final g = gains[d];
    for (var i = delaySamples; i < buf.length; i++) {
      buf[i] += buf[i - delaySamples] * g;
    }
  }
}

void _normalize(Float64List buf, double targetPeak) {
  var peak = 0.0;
  for (final v in buf) {
    final a = v.abs();
    if (a > peak) peak = a;
  }
  if (peak < 1e-9) return;
  final scale = targetPeak / peak;
  for (var i = 0; i < buf.length; i++) {
    buf[i] *= scale;
  }
}

void _crossfadeLoop(Float64List samples, int fadeLen) {
  final n = samples.length;
  for (var i = 0; i < fadeLen; i++) {
    final t = i / fadeLen;
    final a = samples[i];
    final b = samples[n - fadeLen + i];
    samples[i] = a * t + b * (1 - t);
    samples[n - fadeLen + i] = b * t + a * (1 - t);
  }
}

void _writeWav(String path, Int16List samples, int sampleRate) {
  final dataSize = samples.length * 2;
  final bytes = BytesBuilder();

  void writeString(String s) => bytes.add(s.codeUnits);
  void writeInt32(int v) {
    final b = ByteData(4)..setInt32(0, v, Endian.little);
    bytes.add(b.buffer.asUint8List());
  }

  void writeInt16(int v) {
    final b = ByteData(2)..setInt16(0, v, Endian.little);
    bytes.add(b.buffer.asUint8List());
  }

  writeString('RIFF');
  writeInt32(36 + dataSize);
  writeString('WAVE');
  writeString('fmt ');
  writeInt32(16);
  writeInt16(1);
  writeInt16(1);
  writeInt32(sampleRate);
  writeInt32(sampleRate * 2);
  writeInt16(2);
  writeInt16(16);
  writeString('data');
  writeInt32(dataSize);

  final dataBytes = ByteData(dataSize);
  for (var i = 0; i < samples.length; i++) {
    dataBytes.setInt16(i * 2, samples[i], Endian.little);
  }
  bytes.add(dataBytes.buffer.asUint8List());

  final out = File(path);
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(bytes.toBytes());
}
