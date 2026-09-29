import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraCallScreen extends StatefulWidget {
  final String channel;
  final bool videoEnabled;
  final String title;
  final Map<String, dynamic> tokenPayload;

  const AgoraCallScreen({
    super.key,
    required this.channel,
    required this.videoEnabled,
    required this.title,
    required this.tokenPayload,
  });

  @override
  State<AgoraCallScreen> createState() => _AgoraCallScreenState();
}

class _AgoraCallScreenState extends State<AgoraCallScreen> {
  RtcEngine? _engine;
  bool _joined = false;
  int? _remoteUid;
  bool _micMuted = false;
  bool _cameraOff = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  Future<void> _init() async {
    final mic = await Permission.microphone.request();
    if (!widget.videoEnabled && mic != PermissionStatus.granted) {
      if (mounted) {
        setState(() {
          _error = mic.isPermanentlyDenied
              ? 'Microphone access is blocked. Open Settings and allow microphone access.'
              : 'Microphone permission denied';
        });
      }
      return;
    }

    if (widget.videoEnabled) {
      final cam = await Permission.camera.request();
      if (mic != PermissionStatus.granted || cam != PermissionStatus.granted) {
        if (mounted) {
          setState(() {
            _error = mic.isPermanentlyDenied || cam.isPermanentlyDenied
                ? 'Camera or microphone access is blocked. Open Settings and allow both permissions.'
                : 'Camera/Microphone permission denied';
          });
        }
        return;
      }
    }

    final appId = widget.tokenPayload['app_id']?.toString() ?? '';
    final token = widget.tokenPayload['token']?.toString() ?? '';
    final uid = (widget.tokenPayload['uid'] as num?)?.toInt() ?? 0;
    if (appId.isEmpty || token.isEmpty) {
      if (mounted) setState(() => _error = 'Invalid call credentials');
      return;
    }

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: appId));
    await engine.enableAudio();
    if (widget.videoEnabled) {
      await engine.enableVideo();
      await engine.startPreview();
    }

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (mounted) setState(() => _joined = true);
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (mounted) setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (mounted) setState(() => _remoteUid = null);
        },
        onError: (err, _) {
          if (mounted) setState(() => _error = 'Call error: $err');
        },
      ),
    );

    await engine.joinChannel(
      token: token,
      channelId: widget.channel,
      uid: uid,
      options: ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    if (mounted) setState(() => _engine = engine);
  }

  Widget _buildRemoteVideo() {
    if (!widget.videoEnabled) {
      return const Center(
        child: Text('Audio call', style: TextStyle(color: Colors.white)),
      );
    }
    if (_engine == null) {
      return const SizedBox.shrink();
    }
    if (_remoteUid == null) {
      return const Center(
        child: Text('Waiting for participant...', style: TextStyle(color: Colors.white70)),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(uid: _remoteUid),
        connection: RtcConnection(channelId: widget.channel),
      ),
    );
  }

  Widget _buildLocalPreview() {
    if (!widget.videoEnabled || _cameraOff || _engine == null) return const SizedBox.shrink();
    return Positioned(
      right: 16,
      bottom: 120,
      width: 110,
      height: 150,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _engine!,
            canvas: const VideoCanvas(uid: 0),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: openAppSettings,
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                Positioned.fill(child: _buildRemoteVideo()),
                _buildLocalPreview(),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 32,
                        color: Colors.white,
                        icon: Icon(_micMuted ? Icons.mic_off : Icons.mic),
                        onPressed: () async {
                          final next = !_micMuted;
                          await _engine?.muteLocalAudioStream(next);
                          if (mounted) setState(() => _micMuted = next);
                        },
                      ),
                      const SizedBox(width: 12),
                      FloatingActionButton(
                        backgroundColor: Colors.redAccent,
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(Icons.call_end),
                      ),
                      const SizedBox(width: 12),
                      if (widget.videoEnabled)
                        IconButton(
                          iconSize: 32,
                          color: Colors.white,
                          icon: Icon(_cameraOff ? Icons.videocam_off : Icons.videocam),
                          onPressed: () async {
                            final next = !_cameraOff;
                            await _engine?.muteLocalVideoStream(next);
                            if (mounted) setState(() => _cameraOff = next);
                          },
                        ),
                    ],
                  ),
                ),
                if (!_joined)
                  const Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text('Connecting...', style: TextStyle(color: Colors.white70)),
                    ),
                  ),
              ],
            ),
    );
  }
}
