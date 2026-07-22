// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:tencent_cloud_chat_common/tencent_cloud_chat.dart';
import 'package:tencent_cloud_chat_common/utils/tencent_cloud_chat_utils.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_state_widget.dart';
import 'package:tencent_cloud_chat_common/base/tencent_cloud_chat_theme_widget.dart';

GlobalKey trashIconKey = GlobalKey();

class RecordInfo {
  final String path;
  final int duration;

  RecordInfo({
    required this.duration,
    required this.path,
  });
}

class TencentCloudChatMessageInputRecording extends StatefulWidget {
  final bool isRecording;
  final ValueChanged<RecordInfo> onRecordFinish;

  const TencentCloudChatMessageInputRecording({
    super.key,
    required this.isRecording,
    required this.onRecordFinish,
  });

  @override
  State<TencentCloudChatMessageInputRecording> createState() =>
      TencentCloudChatMessageInputRecordingState();
}

class TencentCloudChatMessageInputRecordingState
    extends TencentCloudChatState<TencentCloudChatMessageInputRecording>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeAnimationController;
  bool _isRecording = false;
  double _recordingProgress = 0.0;
  int _recordingDuration = 0;
  AudioRecorder? _audioRecorder;
  Timer? _timer;
  bool _isFingerOverDelete = false;
  final maxDuration = 60000; // 1 minute
  PointerRoute? _pointerEventListener;
  int _recordingGeneration = 0;

  @override
  void initState() {
    super.initState();
    _shakeAnimationController = AnimationController(
        duration: const Duration(milliseconds: 100), vsync: this);
    _initRecorder();
  }

  _initRecorder() {}

  Future<void> _provideHapticFeedback(
    Future<void> Function() feedback,
  ) async {
    try {
      await feedback();
    } catch (e) {
      debugPrint('Recording haptic feedback failed: $e');
    }
  }

  @override
  void dispose() {
    _recordingGeneration++;
    _removePointerEventListener();
    _timer?.cancel();
    _shakeAnimationController.dispose();
    final recorder = _audioRecorder;
    _audioRecorder = null;
    if (recorder != null) {
      unawaited(_disposeRecorderQuietly(recorder));
    }
    super.dispose();
  }

  Future<void> startRecording() async {
    final recorder = AudioRecorder();
    final generation = ++_recordingGeneration;
    final previousRecorder = _audioRecorder;
    _audioRecorder = recorder;
    if (previousRecorder != null) {
      unawaited(_disposeRecorderQuietly(previousRecorder));
    }
    _timer?.cancel();

    // Check and request permission if needed
    if (!await recorder.hasPermission()) {
      await _disposeCurrentRecorderIfUnchanged(generation, recorder);
      return;
    }
    if (!await _continueRecordingStart(generation, recorder)) return;

    _shakeAnimationController.repeat(reverse: true);
    setState(() {
      _isRecording = true;
      _recordingProgress = 0.0;
      _recordingDuration = 0;
    });

    // Get the file path
    final directory = await getTemporaryDirectory();
    if (!await _continueRecordingStart(generation, recorder)) return;
    final recordingDirectory =
        Pertypath().join(directory.path, 'tencent_cloud_chat', 'recordings');
    await Directory(recordingDirectory).create(recursive: true);
    if (!await _continueRecordingStart(generation, recorder)) return;
    final uuid = DateTime.now().millisecondsSinceEpoch;
    final path = Pertypath().join(recordingDirectory, '$uuid.m4a');

    const encoder = AudioEncoder.aacLc;
    final isSupported = await recorder.isEncoderSupported(
      encoder,
    );
    if (!await _continueRecordingStart(generation, recorder)) return;
    debugPrint('${encoder.name} supported: $isSupported');
    final devs = await recorder.listInputDevices();
    if (!await _continueRecordingStart(generation, recorder)) return;
    debugPrint(devs.toString());
    const androidConfig = AndroidRecordConfig(
        useLegacy: true, audioSource: AndroidAudioSource.mic);
    const config = RecordConfig(encoder: encoder, androidConfig: androidConfig);

    // Start recording to file
    await recorder.start(config, path: path);
    if (!await _continueRecordingStart(
      generation,
      recorder,
      stopFirst: true,
    )) {
      return;
    }
    await _provideHapticFeedback(HapticFeedback.mediumImpact);
    if (!await _continueRecordingStart(
      generation,
      recorder,
      stopFirst: true,
    )) {
      return;
    }
    _addPointerEventListener();
    _startTimer();
  }

  bool _isCurrentRecordingStart(int generation, AudioRecorder recorder) {
    return mounted &&
        generation == _recordingGeneration &&
        identical(_audioRecorder, recorder);
  }

  Future<bool> _continueRecordingStart(
    int generation,
    AudioRecorder recorder, {
    bool stopFirst = false,
  }) async {
    if (_isCurrentRecordingStart(generation, recorder)) return true;
    if (!identical(_audioRecorder, recorder)) return false;
    _audioRecorder = null;
    if (stopFirst) await _stopRecorderQuietly(recorder);
    await _disposeRecorderQuietly(recorder);
    return false;
  }

  Future<void> _disposeCurrentRecorderIfUnchanged(
    int generation,
    AudioRecorder recorder,
  ) async {
    if (generation == _recordingGeneration &&
        identical(_audioRecorder, recorder)) {
      _audioRecorder = null;
    }
    await _disposeRecorderQuietly(recorder);
  }

  Future<void> _stopRecorderQuietly(AudioRecorder recorder) async {
    try {
      await recorder.stop();
    } catch (e) {
      debugPrint('Recording stop during cleanup failed: $e');
    }
  }

  Future<void> _disposeRecorderQuietly(AudioRecorder recorder) async {
    try {
      await recorder.dispose();
    } catch (e) {
      debugPrint('Recording dispose failed: $e');
    }
  }

  void _addPointerEventListener() {
    _removePointerEventListener();
    // Add global pointer event listener
    _pointerEventListener = (event) {
      if (!mounted || event is! PointerMoveEvent || !_isRecording) return;
      final trashIconRenderObject =
          trashIconKey.currentContext?.findRenderObject();
      if (trashIconRenderObject is RenderBox) {
        final trashIconRenderBox = trashIconRenderObject;
        final trashIconOffset = trashIconRenderBox.localToGlobal(Offset.zero);
        final trashIconSize = trashIconRenderBox.size;
        final isOverDeleteIcon = event.position.dx >= trashIconOffset.dx &&
            event.position.dx <= trashIconOffset.dx + trashIconSize.width &&
            event.position.dy >= trashIconOffset.dy &&
            event.position.dy <= trashIconOffset.dy + trashIconSize.height;

        if (isOverDeleteIcon != _isFingerOverDelete) {
          setState(() {
            _isFingerOverDelete = isOverDeleteIcon;
          });

          if (_isFingerOverDelete) {
            _shakeAnimationController.repeat(reverse: true);
          } else {
            _shakeAnimationController.stop();
            _shakeAnimationController.reset();
          }
        }
      }
    };
    WidgetsBinding.instance.pointerRouter
        .addGlobalRoute(_pointerEventListener!);
  }

  void _removePointerEventListener() {
    final listener = _pointerEventListener;
    if (listener == null) return;
    WidgetsBinding.instance.pointerRouter.removeGlobalRoute(listener);
    _pointerEventListener = null;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _recordingDuration += 10;
        _recordingProgress = _recordingDuration / maxDuration;
      });

      final adjustMaxDuration = maxDuration - 800;
      if (_recordingDuration >= adjustMaxDuration) {
        timer.cancel();
        stopRecording(cancel: false);
      }
    });
  }

  Future<void> stopRecording({required bool cancel}) async {
    try {
      _recordingGeneration++;
      final wasRecording = _isRecording;
      _shakeAnimationController.stop();
      _shakeAnimationController.reset();
      _timer?.cancel();
      _timer = null;
      _isFingerOverDelete = false;
      _removePointerEventListener();

      final recorder = _audioRecorder;
      _audioRecorder = null;
      final recordedFile = await recorder?.stop();
      if (wasRecording) {
        await _provideHapticFeedback(
          cancel ? HapticFeedback.heavyImpact : HapticFeedback.lightImpact,
        );
      }
      if (!cancel && TencentCloudChatUtils.checkString(recordedFile) != null) {
        widget.onRecordFinish(RecordInfo(
            duration: (_recordingDuration / 1000).ceil(), path: recordedFile!));
      } else {
        File recordedFileInstance = File(recordedFile ?? "");
        recordedFileInstance.delete();
      }
      if (recorder != null) {
        await _disposeRecorderQuietly(recorder);
      }

      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordingProgress = 0.0;
        _recordingDuration = 0;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget defaultBuilder(BuildContext context) {
    return TencentCloudChatThemeWidget(
      build: (context, colorTheme, textStyle) => Container(
        color: colorTheme.inputAreaBackground,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              key: trashIconKey,
              padding: EdgeInsets.only(
                bottom: getSquareSize(8),
                right: getSquareSize(14),
                left: getSquareSize(8),
                top: getSquareSize(8),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isFingerOverDelete
                      ? colorTheme.info
                      : Colors.transparent,
                  border: _isFingerOverDelete
                      ? Border.all(color: colorTheme.info, width: 22)
                      : Border.all(color: Colors.transparent, width: 0),
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: _isRecording
                        ? (_isFingerOverDelete
                            ? colorTheme.backgroundColor
                            : colorTheme.primaryColor)
                        : Colors.transparent,
                    fontSize: _isFingerOverDelete
                        ? textStyle.inputAreaIcon + 14
                        : textStyle.inputAreaIcon + 6,
                  ),
                  child: Text(
                    String.fromCharCode(Icons.delete.codePoint),
                    style: const TextStyle(fontFamily: 'MaterialIcons'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: AnimatedContainer(
                padding: EdgeInsets.symmetric(
                    vertical: getHeight(8), horizontal: getWidth(16)),
                decoration: BoxDecoration(
                  color: _isRecording
                      ? colorTheme.primaryColor
                      : Colors.transparent,
                  border: _isRecording
                      ? Border.all(color: colorTheme.primaryColor)
                      : Border.all(color: Colors.transparent),
                  borderRadius: BorderRadius.circular(25),
                ),
                duration: const Duration(milliseconds: 200),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: getWidth(48),
                      child: Text(
                        '${(_recordingDuration ~/ 1000).toString().padLeft(2, '0')}:${((_recordingDuration % 1000) ~/ 10).toString().padLeft(2, '0')}',
                        style: TextStyle(
                            fontSize: getFontSize(14),
                            color: colorTheme.backgroundColor),
                        overflow: TextOverflow.fade,
                        maxLines: 1,
                      ),
                    ),
                    SizedBox(width: getWidth(8)),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _recordingProgress,
                        backgroundColor: Colors.transparent,
                        color: colorTheme.backgroundColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
