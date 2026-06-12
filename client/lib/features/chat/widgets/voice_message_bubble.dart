import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../message.dart';
import '../../media/attachment_envelope.dart';
import '../../media/media_manager.dart';
import '../../../core/providers.dart';
import '../../../design_system/colors.dart';
import '../../../design_system/typography.dart';
import '../../../design_system/spacing.dart';
import '../../../design_system/haptics.dart';

import '../../../core/stability_tracker.dart';

class VoiceMessageBubble extends ConsumerStatefulWidget {
  final Message message;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  ConsumerState<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends ConsumerState<VoiceMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  
  File? _audioFile;
  MediaState _mediaState = MediaState.NOT_DOWNLOADED;
  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _statePlayerSub;

  @override
  void initState() {
    super.initState();
    StabilityTracker.activeVoiceMessageBubbles++;
    _initMedia();
    
    _statePlayerSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    
    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    
    _posSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    StabilityTracker.activeVoiceMessageBubbles--;
    _stateSub?.cancel();
    _statePlayerSub?.cancel();
    _durSub?.cancel();
    _posSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _initMedia() async {
    if (widget.message.metadata == null || widget.message.metadata?['media_id'] == null) return;
    final envelope = AttachmentEnvelope.fromJson(widget.message.metadata!);
    final mediaId = envelope.mediaId;
    final mediaManager = ref.read(mediaManagerProvider);

    setState(() {
      _mediaState = mediaManager.getMediaState(mediaId, isThumbnail: false);
    });

    _stateSub = mediaManager.stateStream.listen((update) {
      if (update.mediaId == mediaId && !update.isThumbnail) {
        if (mounted) {
          setState(() => _mediaState = update.state);
          if (update.state == MediaState.READY) {
            _loadAudioFile();
          } else if (update.state == MediaState.FAILED) {
          }
        }
      }
    });

    if (_mediaState == MediaState.READY) {
      _loadAudioFile();
    }
  }

  Future<void> _loadAudioFile() async {
    if (widget.message.metadata == null || widget.message.metadata?['media_id'] == null) return;
    final envelope = AttachmentEnvelope.fromJson(widget.message.metadata!);
    final mediaManager = ref.read(mediaManagerProvider);
    final relay = await ref.read(activeRelayProvider.future);
    final identity = ref.read(identityServiceProvider).currentIdentity;

    if (relay == null || identity == null) {
      return;
    }

    try {
      final file = await mediaManager.getMedia(
        envelope: envelope,
        relay: relay,
        myXidKeyPair: identity.x25519KeyPair,
        isThumbnail: false,
        messageId: widget.message.id,
      );
      if (mounted) {
        setState(() => _audioFile = file);
      }
    } catch (_) {
      // Ignore
    }
  }

  void _togglePlayback() async {
    if (_audioFile == null) {
      _download();
      return;
    }

    AppHaptics.light();
    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(_audioFile!.path));
    }
  }

  void _download() async {
    if (widget.message.metadata == null || widget.message.metadata?['media_id'] == null) return;
    if (_mediaState == MediaState.DOWNLOADING || 
        _mediaState == MediaState.DECRYPTING || 
        _mediaState == MediaState.VERIFYING) {
      return;
    }

    final mediaManager = ref.read(mediaManagerProvider);
    final envelope = AttachmentEnvelope.fromJson(widget.message.metadata!);
    final relay = await ref.read(activeRelayProvider.future);

    try {
      final identity = ref.read(identityServiceProvider).currentIdentity;
      if (relay == null || identity == null) {
        throw Exception('Active relay or identity is null');
      }

      final file = await mediaManager.getMedia(
        envelope: envelope,
        relay: relay,
        myXidKeyPair: identity.x25519KeyPair,
        isThumbnail: false,
        messageId: widget.message.id,
      );
      if (mounted) {
        setState(() {
          _audioFile = file;
          _mediaState = MediaState.READY;
        });
        await _player.play(DeviceFileSource(file.path));
      }
    } catch (_) {
      // Ignore
    }
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isPlaying = _playerState == PlayerState.playing;
    final isProcessing = _mediaState == MediaState.DOWNLOADING || 
                         _mediaState == MediaState.DECRYPTING || 
                         _mediaState == MediaState.VERIFYING;
                         
    final durationMs = widget.message.metadata?['duration_ms'] as int? ?? 0;
    final displayDuration = _duration > Duration.zero ? _duration : Duration(milliseconds: durationMs);

    return Container(
      width: 240,
      padding: const EdgeInsets.all(AppSpacing.s),
      child: Row(
        children: [
          GestureDetector(
            onTap: isProcessing ? null : _togglePlayback,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isMe ? colors.primaryText.withAlpha(20) : colors.ghostAccent.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: isProcessing
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: widget.isMe ? colors.primaryText : colors.ghostAccent,
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: widget.isMe ? colors.primaryText : colors.ghostAccent,
                    inactiveTrackColor: colors.secondaryText.withAlpha(40),
                    thumbColor: widget.isMe ? colors.primaryText : colors.ghostAccent,
                  ),
                  child: Slider(
                    value: _position.inMilliseconds.toDouble(),
                    max: displayDuration.inMilliseconds.toDouble().clamp(1, double.infinity),
                    onChanged: (val) {
                      _player.seek(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: AppTypography.caption(context).copyWith(fontSize: 8),
                      ),
                      Text(
                        _formatDuration(displayDuration),
                        style: AppTypography.caption(context).copyWith(fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

