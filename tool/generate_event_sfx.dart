// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Süpernova, meteor ve uyarı ses efektlerini üretir.
Future<void> main() async {
  const sampleRate = 44100;

  await _generateAndConvert(
    sampleRate: sampleRate,
    wavPath: 'assets/audio/_temp_event_warning.wav',
    mp3Path: 'assets/audio/event_warning.mp3',
    builder: _buildEventWarning,
    durationSec: 5.0,
    loopable: true,
  );

  await _generateAndConvert(
    sampleRate: sampleRate,
    wavPath: 'assets/audio/_temp_supernova.wav',
    mp3Path: 'assets/audio/supernova_explosion.mp3',
    builder: _buildSupernovaExplosion,
    durationSec: 1.8,
    loopable: false,
  );

  await _generateAndConvert(
    sampleRate: sampleRate,
    wavPath: 'assets/audio/_temp_meteor_impact.wav',
    mp3Path: 'assets/audio/meteor_impact.mp3',
    builder: _buildMeteorImpact,
    durationSec: 0.45,
    loopable: false,
  );

  await _generateAndConvert(
    sampleRate: sampleRate,
    wavPath: 'assets/audio/_temp_meteor_whoosh.wav',
    mp3Path: 'assets/audio/meteor_whoosh.mp3',
    builder: _buildMeteorWhoosh,
    durationSec: 0.35,
    loopable: false,
  );

  print('Tüm olay ses efektleri hazır.');
}

Future<void> _generateAndConvert({
  required int sampleRate,
  required String wavPath,
  required String mp3Path,
  required Float64List Function(int sampleRate, double durationSec) builder,
  required double durationSec,
  required bool loopable,
}) async {
  final buf = builder(sampleRate, durationSec);
  if (loopable) {
    _crossfadeLoop(buf, (sampleRate * 0.08).round());
  }
  _normalize(buf, 0.82);

  final pcm = Int16List(buf.length);
  for (var i = 0; i < buf.length; i++) {
    pcm[i] = (buf[i].clamp(-1.0, 1.0) * 30000).round();
  }

  _writeWav(wavPath, pcm, sampleRate);
  print('Wrote $wavPath');

  final ffmpeg = await _findFfmpeg();
  if (ffmpeg == null) {
    print('ffmpeg bulunamadı — $mp3Path atlandı.');
    exit(1);
  }

  final result = await Process.run(ffmpeg, [
    '-y',
    '-i',
    wavPath,
    '-codec:a',
    'libmp3lame',
    '-b:a',
    '160k',
    '-ar',
    '44100',
    mp3Path,
  ]);

  if (result.exitCode != 0) {
    print('ffmpeg hatası ($mp3Path): ${result.stderr}');
    exit(1);
  }

  await File(wavPath).delete();
  print('Wrote $mp3Path (${File(mp3Path).lengthSync()} bytes)');
}

Float64List _buildEventWarning(int sampleRate, double durationSec) {
  final n = (sampleRate * durationSec).round();
  final buf = Float64List(n);
  final rng = math.Random(42);

  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    var s = 0.0;

    // Derin gerilim drone'u.
    s += math.sin(2 * math.pi * 55 * t) * 0.12;
    s += math.sin(2 * math.pi * 82.5 * t + 0.4) * 0.08;

    // İkili alarm tonu — süpernova / meteor uyarısı.
    final pulse = (math.sin(2 * math.pi * 2.2 * t) + 1) * 0.5;
    final alarmEnv = pulse > 0.55 ? 1.0 : 0.15;
    final alarmFreq = pulse > 0.55 ? 880.0 : 660.0;
    s += math.sin(2 * math.pi * alarmFreq * t) * alarmEnv * 0.22;
    s += math.sin(2 * math.pi * alarmFreq * 2 * t) * alarmEnv * 0.08;

    // Kısa bip ritmi.
    final beat = (t * 3.5) % 1.0;
    if (beat < 0.12) {
      s += math.sin(2 * math.pi * 1320 * t) * 0.14;
    }

    // Hafif statik gerilim.
    s += (rng.nextDouble() * 2 - 1) * 0.018 * (0.4 + pulse * 0.6);

    final fadeIn = (t / 0.25).clamp(0.0, 1.0);
    final fadeOut = ((durationSec - t) / 0.35).clamp(0.0, 1.0);
    buf[i] = s * fadeIn * fadeOut;
  }

  _applyLowPass(buf, 3);
  return buf;
}

Float64List _buildSupernovaExplosion(int sampleRate, double durationSec) {
  final n = (sampleRate * durationSec).round();
  final buf = Float64List(n);
  final rng = math.Random(7);

  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    var s = 0.0;

    // Ani gürültü patlaması.
    final burstEnv = math.exp(-t * 6.5);
    s += (rng.nextDouble() * 2 - 1) * burstEnv * 0.55;

    // Alçalan bas rögarı.
    final bassFreq = 120 * math.exp(-t * 2.8) + 35;
    s += math.sin(2 * math.pi * bassFreq * t) * math.exp(-t * 3.2) * 0.65;

    // Parlama sweep.
    final sweep = 2000 * math.exp(-t * 4.5) + 180;
    s += math.sin(2 * math.pi * sweep * t) * math.exp(-t * 5.0) * 0.18;

    // Uzun yankı kuyruğu.
    final tail = math.exp(-t * 1.6);
    s += math.sin(2 * math.pi * 48 * t) * tail * 0.28;
    s += (rng.nextDouble() * 2 - 1) * tail * 0.06;

    buf[i] = s;
  }

  _applyLowPass(buf, 4);
  _applyReverb(buf, sampleRate, [180, 320, 520], [0.35, 0.25, 0.15]);
  return buf;
}

Float64List _buildMeteorImpact(int sampleRate, double durationSec) {
  final n = (sampleRate * durationSec).round();
  final buf = Float64List(n);
  final rng = math.Random(19);

  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    var s = 0.0;

    final hitEnv = math.exp(-t * 18);
    s += (rng.nextDouble() * 2 - 1) * hitEnv * 0.42;
    s += math.sin(2 * math.pi * (220 - t * 180) * t) * hitEnv * 0.35;
    s += math.sin(2 * math.pi * 90 * t) * math.exp(-t * 12) * 0.25;

    // Kıvılcım tıkırtısı.
    if (t < 0.08) {
      s += math.sin(2 * math.pi * 2400 * t) * (1 - t / 0.08) * 0.12;
    }

    buf[i] = s;
  }

  _applyLowPass(buf, 2);
  return buf;
}

Float64List _buildMeteorWhoosh(int sampleRate, double durationSec) {
  final n = (sampleRate * durationSec).round();
  final buf = Float64List(n);
  final rng = math.Random(31);

  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final progress = t / durationSec;
    var s = 0.0;

    final env = math.sin(math.pi * progress);
    final freq = 900 + progress * 1400;
    s += math.sin(2 * math.pi * freq * t) * env * 0.12;
    s += (rng.nextDouble() * 2 - 1) * env * 0.22;

    buf[i] = s;
  }

  _applyLowPass(buf, 2);
  return buf;
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
