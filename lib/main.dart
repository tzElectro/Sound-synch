import 'dart:io';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:audio_capture/ui/bars.dart';
import 'package:logging/logging.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/scheduler.dart';
import 'package:audio_capture/audio_packet_display.dart'; // Adjust path as needed

/// Demostrate how to use flutter_recorder.
///
/// The silence detection and the visualizer works when using [PCMFormat.f32].
/// Writing audio stream to file is not implemented on Web.
void main() async {
  // The `flutter_recorder` package logs everything
  // (from severe warnings to fine debug messages)
  // using the standard `package:logging`.
  // You can listen to the logs as shown below.
  Logger.root.level = kDebugMode ? Level.FINE : Level.INFO;
  Logger.root.onRecord.listen((record) {
    dev.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      zone: record.zone,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });

  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Flutter Recorder')),
        body: MyApp(),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class FFTDisplay extends StatefulWidget {
  const FFTDisplay({super.key});

  @override
  State<FFTDisplay> createState() => _FFTDisplayState();
}

class _FFTDisplayState extends State<FFTDisplay> {
  List<double> fftValues = List.filled(16, 0.0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration _) {
    final fft = Recorder.instance.getFft();
    if (fft.isEmpty) return;

    setState(() {
      fftValues = fft.take(16).toList(); // Just show first 16 raw values
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
          'Raw FFT Data (first 16 values)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: fftValues
              .map(
                (v) => Text(
                  v.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 12),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _MyAppState extends State<MyApp> with TickerProviderStateMixin {
  Directory? savingDir;
  final format = PCMFormat.f32le;
  final sampleRate = 22050;
  final channels = RecorderChannels.mono;
  final recorder = Recorder.instance;
  String? filePath;
  var thresholdDb = -20.0;
  var silenceDuration = 2.0;
  var secondsOfAudioToWriteBefore = 0.0;

  File? file;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      Permission.microphone.request().isGranted.then((value) async {
        if (!value) {
          await [Permission.microphone].request();
        }
      });
    }

    /// Listen to audio data stream. The data is received as Uint8List.
    recorder.uint8ListStream.listen((data) {
      /// Write the PCM data to file. It can then be imported with the correct
      /// parameters with for example Audacity.
      /// Not testing on Web platform.
      if (!kIsWeb) {
        file?.writeAsBytesSync(
          // If you want a conversion, call one of the `to*List` methods.
          // data.toF32List(from: format).buffer.asUint8List(),
          data.rawData,
          mode: FileMode.writeOnlyAppend,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            /// List capture devices, init, start, deinit
            Wrap(
              runSpacing: 6,
              spacing: 6,
              children: [
                OutlinedButton(
                  onPressed: () {
                    showDeviceListDialog();
                  },
                  child: const Text('listCaptureDevices'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await recorder.init(
                        format: format,
                        sampleRate: sampleRate,
                        channels: channels,
                      );
                    } on Exception catch (e) {
                      debugPrint('-------------- init() error: $e\n');
                    }
                  },
                  child: const Text('init'),
                ),
                OutlinedButton(
                  onPressed: () {
                    try {
                      recorder.start();
                    } on Exception catch (e) {
                      debugPrint('-------------- start() error: $e\n');
                    }
                  },
                  child: const Text('start'),
                ),
                OutlinedButton(
                  onPressed: () {
                    recorder.deinit();
                  },
                  child: const Text('deinit'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            /// Recording
            Wrap(
              runSpacing: 6,
              spacing: 6,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    try {
                      /// Asking for file path to store the audio file.
                      /// On web platform, it will be asked internally
                      /// from the browser.
                      if (!kIsWeb) {
                        final downloadsDir = await getDownloadsDirectory();
                        filePath = '${downloadsDir!.path}/flutter_recorder.wav';
                        recorder.startRecording(completeFilePath: filePath!);
                      } else {
                        recorder.startRecording();
                      }
                    } on Exception catch (e) {
                      debugPrint('-------------- startRecording() $e\n');
                    }
                  },
                  child: const Text('Start recording'),
                ),
                ElevatedButton(
                  onPressed: () {
                    recorder.setPauseRecording(pause: true);
                  },
                  child: const Text('Pause recording'),
                ),
                ElevatedButton(
                  onPressed: () {
                    recorder.setPauseRecording(pause: false);
                  },
                  child: const Text('UN-Pause recording'),
                ),
                ElevatedButton(
                  onPressed: () {
                    recorder.stopRecording();
                    if (!kIsWeb) {
                      debugPrint('Audio recorded to "$filePath"');
                      showFileRecordedDialog(filePath!);
                    }
                  },
                  child: const Text('Stop recording'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            /// Streaming
            Wrap(
              runSpacing: 6,
              spacing: 6,
              children: [
                CircularProgressIndicator(),
                OutlinedButton(
                  onPressed: () async {
                    recorder.startStreamingData();

                    if (!kIsWeb) {
                      savingDir = await getDownloadsDirectory();
                      if (savingDir == null) {
                        debugPrint('Cannot get download directory!');
                        return;
                      }
                      savingDir = Directory(
                        '${savingDir!.path}/flutter_recorder',
                      );
                      savingDir!.createSync();

                      file = File(
                        '${savingDir?.path}/fr_${sampleRate}_${format.name}_'
                        '${channels.count}.pcm',
                      );
                      try {
                        if (file?.existsSync() ?? false) {
                          file?.deleteSync();
                        }
                      } catch (e) {
                        debugPrint('Error deleting file: $e');
                      }
                    }
                  },
                  child: const Text('start stream'),
                ),
                OutlinedButton(
                  onPressed: () {
                    recorder.stopStreamingData();
                  },
                  child: const Text('stop stream'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            /// The silence detection is available only with f32 format and
            /// the visualization is adapted only with that format.
            if (format == PCMFormat.f32le)
              Column(
                children: [
                  Column(
                    children: [
                      StreamBuilder(
                        stream: recorder.silenceChangedEvents,
                        builder: (context, snapshot) {
                          return ColoredBox(
                            color: snapshot.hasData && snapshot.data!.isSilent
                                ? Colors.green
                                : Colors.red,
                            child: SizedBox(
                              width: 70,
                              height: 50,
                              child: Center(
                                child: Text(
                                  recorder.getVolumeDb().toStringAsFixed(1),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        runSpacing: 6,
                        spacing: 6,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              recorder.setSilenceDetection(
                                enable: true,
                                onSilenceChanged: (isSilent, decibel) {
                                  /// Here you can check if silence is changed.
                                  /// Or you can do the same thing with the Stream
                                  /// [Recorder.instance.silenceChangedEvents]
                                  // debugPrint('SILENCE CHANGED: $isSilent, $decibel');
                                },
                              );
                              recorder.setSilenceThresholdDb(-27);
                              recorder.setSilenceDuration(0.5);
                              recorder.setSecondsOfAudioToWriteBefore(0.0);
                              setState(() {
                                thresholdDb = -27;
                                silenceDuration = 0.5;
                                secondsOfAudioToWriteBefore = 0;
                              });
                            },
                            child: const Text(
                              'setSilenceDetection ON -27, 0.5, 0.0',
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              recorder.setSilenceDetection(enable: false);
                            },
                            child: const Text('setSilenceDetection OFF'),
                          ),
                        ],
                      ),

                      // Threshold dB slider
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            'Threshold: ${thresholdDb.toStringAsFixed(1)}dB',
                          ),
                          Expanded(
                            child: Slider(
                              value: thresholdDb,
                              min: -100,
                              max: 0,
                              label: thresholdDb.toStringAsFixed(1),
                              onChanged: (value) {
                                recorder.setSilenceThresholdDb(value);
                                setState(() {
                                  thresholdDb = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      // Silence duration slider
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            'Silence duration: '
                            '${silenceDuration.toStringAsFixed(1)}',
                          ),
                          Expanded(
                            child: Slider(
                              value: silenceDuration,
                              min: 0,
                              max: 10,
                              label: silenceDuration.toStringAsFixed(1),
                              onChanged: (value) {
                                recorder.setSilenceDuration(value);
                                setState(() {
                                  silenceDuration = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      // Silence duration slider
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            'Write before: '
                            '${secondsOfAudioToWriteBefore.toStringAsFixed(1)}',
                          ),
                          Expanded(
                            child: Slider(
                              value: secondsOfAudioToWriteBefore,
                              min: 0,
                              max: 5,
                              label: silenceDuration.toStringAsFixed(1),
                              onChanged: (value) {
                                recorder.setSecondsOfAudioToWriteBefore(value);
                                setState(() {
                                  secondsOfAudioToWriteBefore = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Bars(),
                  const SizedBox(height: 20),
                  const FFTDisplay(),
                  const AudioPacketDisplay(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> showFileRecordedDialog(String filePath) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Recording saved!'),
          content: Text('Audio saved to:\n$filePath'),
          actions: <Widget>[
            TextButton(
              child: const Text('open'),
              onPressed: () async {
                OpenFilex.open(filePath, type: 'audio/wav');
              },
            ),
            TextButton(
              child: const Text('close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> showDeviceListDialog() async {
    final devices = recorder.listCaptureDevices();
    String devicesString = devices
        .asMap()
        .entries
        .map((entry) {
          return '${entry.value.id} ${entry.value.isDefault ? 'DEFAULT' : ''} - '
              ' ${entry.value.name}';
        })
        .join('\n\n');

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Available input devices'),
          content: Text(devicesString),
          actions: <Widget>[
            const Text(''),
            TextButton(
              child: const Text('close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
