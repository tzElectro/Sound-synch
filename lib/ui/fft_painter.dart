// TODO Implement this library.// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:flutter_recorder/flutter_recorder.dart';

/// Custom painter to draw the FFT data.
class FftPainter extends CustomPainter {
  const FftPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (!Recorder.instance.isDeviceStarted()) return;

    final fftData = Recorder.instance.getFft(alwaysReturnData: true);
    // Using `alwaysReturnData: true` this will always return a non-empty list
    // even if the audio data is the same as the previous one.
    if (fftData.isEmpty) return;
    final barWidth = size.width / 256;

    final paint = Paint()..color = Colors.yellow;

    for (var i = 0; i < 256; i++) {
      late final double barHeight;
      barHeight = size.height * fftData[i];
      canvas.drawRect(
        Rect.fromLTWH(
          barWidth * i,
          size.height - barHeight,
          barWidth,
          barHeight,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FftPainter oldDelegate) {
    return true;
  }
}