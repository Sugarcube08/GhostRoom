import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../design_system/colors.dart';
import '../../../design_system/typography.dart';
import '../../../design_system/spacing.dart';
import '../../../design_system/haptics.dart';

class VoiceRecorder extends StatefulWidget {
  final Function(File file, int durationMs) onRecordingComplete;
  final VoidCallback onCancel;

  const VoiceRecorder({
    super.key,
    required this.onRecordingComplete,
    required this.onCancel,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  final AudioRecorder _recorder = AudioRecorder();
  int _durationSeconds = 0;
  Timer? _timer;
  String? _path;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _path = '${dir.path}/ghost_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        const config = RecordConfig(); // Default config
        
        await _recorder.start(config, path: _path!);
        
        AppHaptics.light();
        setState(() {
          _durationSeconds = 0;
        });
        
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _durationSeconds++);
        });
      }
    } catch (e) {
      widget.onCancel();
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    
    if (path != null && _durationSeconds > 0) {
      AppHaptics.medium();
      widget.onRecordingComplete(File(path), _durationSeconds * 1000);
    } else {
      widget.onCancel();
    }
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      decoration: BoxDecoration(
        color: colors.secondaryBackground,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Icon(Icons.mic, color: colors.error, size: 20),
          const SizedBox(width: AppSpacing.m),
          Text(
            _formatDuration(_durationSeconds),
            style: AppTypography.body(context).copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Text(
              'Recording...',
              style: AppTypography.caption(context).copyWith(
                color: colors.secondaryText.withAlpha(100),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              AppHaptics.light();
              _recorder.stop(); // Ignore result
              widget.onCancel();
            },
            child: Text(
              'CANCEL',
              style: AppTypography.caption(context).copyWith(
                color: colors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.ghostAccent,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
