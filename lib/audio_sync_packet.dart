import 'dart:io';
import 'dart:typed_data';
import 'dart:typed_data'; // for Float32List

Uint8List buildAudioSyncPacket({
  required Float32List fft,
  required double sampleRaw,
  required double sampleSmth,
  required bool peakDetected,
  required int zeroCrossingCount,
  required double fftMagnitude,
  required double fftMajorPeak,
  int frameCounter = 0,
}) {
  final stopwatch = Stopwatch()..start();

  final buffer = ByteData(44);

  // Header: "00002" + null terminator
  const header = "00002";
  for (int i = 0; i < 6; i++) {
    buffer.setUint8(i, i < header.length ? header.codeUnitAt(i) : 0);
  }

  // Pressure (set to zero for now)
  buffer.setUint8(6, 0);
  buffer.setUint8(7, 0);

  // sampleRaw and sampleSmth
  buffer.setFloat32(8, sampleRaw, Endian.little);
  buffer.setFloat32(12, sampleSmth, Endian.little);

  // Peak detection
  buffer.setUint8(16, peakDetected ? 1 : 0);

  // Frame counter
  buffer.setUint8(17, frameCounter);

  // FFT result mapped to 0–255
  for (int i = 0; i < 16; i++) {
    double value = fft.length > i ? fft[i] : 0.0;
    int mapped = ((value.clamp(-1.0, 1.0) + 1.0) * 127.5)
        .round(); // -1 to 1 => 0 to 255
    buffer.setUint8(18 + i, mapped);
  }

  // Zero crossing count
  buffer.setUint16(34, zeroCrossingCount, Endian.little);

  // FFT magnitude and peak frequency
  buffer.setFloat32(36, fftMagnitude, Endian.little);
  buffer.setFloat32(40, fftMajorPeak, Endian.little);

  stopwatch.stop();
  print('Packet build time: ${stopwatch.elapsedMicroseconds} µs');

  return buffer.buffer.asUint8List();
}

Future<void> sendUdpPacket(Uint8List packet, String ip, int port) async {
  try {
    final stopwatch = Stopwatch()..start();

    RawDatagramSocket socket;

    if (kIsWeb) {
      throw UnsupportedError('UDP is not supported on Flutter Web');
    }

    // This works only on Android/iOS/macOS/Windows/Linux
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

    socket.send(packet, InternetAddress(ip), port);
    socket.close();

    stopwatch.stop();
    print('Packet send time: ${stopwatch.elapsedMicroseconds} µs');
  } catch (e) {
    print('UDP send error: $e');
  }
}
