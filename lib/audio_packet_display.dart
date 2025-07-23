import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:audio_capture/audio_sync_packet.dart'; // Make sure this exists

class AudioPacketDisplay extends StatefulWidget {
  const AudioPacketDisplay({super.key});

  @override
  State<AudioPacketDisplay> createState() => _AudioPacketDisplayState();
}

class _AudioPacketDisplayState extends State<AudioPacketDisplay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Uint8List? packet;
  int frameCounter = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration _) {
    final fft = Recorder.instance.getFft();
    if (fft.isEmpty) return;

    final volume = Recorder.instance.getVolumeDb();
    final builtPacket = buildAudioSyncPacket(
      fft: fft,
      sampleRaw: volume,
      sampleSmth: volume * 0.9,
      peakDetected: volume > 0.8,
      zeroCrossingCount: 12, // Replace with real zero-cross logic
      fftMagnitude: fft.map((v) => v.abs()).reduce(max),
      fftMajorPeak: 440.0, // Replace with real peak freq
      frameCounter: frameCounter++,
    );
    sendUdpPacket(
      builtPacket,
      '192.168.1.2',
      11988,
    ); // <-- your WLED IP and port
    setState(() {
      packet = builtPacket;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Audio Sync Packet (Bytes)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        if (packet != null)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: packet!
                .map(
                  (b) => Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.black12,
                    ),
                    child: Text(
                      b.toRadixString(16).padLeft(2, '0').toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
