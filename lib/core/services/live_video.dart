// ─── Live Video ───────────────────────────────────────────────────────────────
// The video of a live stream, carried by LiveKit. The API only hands out
// short-lived tokens (POST /api/streams/:id/video-token); the picture and sound
// travel between the phones and LiveKit.

import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:livekit_client/livekit_client.dart';

import '../api/api_client.dart';

class LiveVideo extends ChangeNotifier {
  Room? _room;
  LocalVideoTrack? _camera;
  bool _closed = false;

  // The picture to show: the tailor's own camera, or the tailor's video for a viewer.
  VideoTrack? get track {
    if (_camera != null) return _camera;
    final room = _room;
    if (room == null) return null;
    for (final participant in room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (track != null && !publication.muted) return track;
      }
    }
    return null;
  }

  bool get connected => _room?.connectionState == ConnectionState.connected;

  static Future<({String url, String token})> _access(String streamId) async {
    final json = objectOf(await ApiClient().post('/streams/$streamId/video-token'));
    return (url: json['url'] as String, token: json['token'] as String);
  }

  // ── Tailor ─────────────────────────────────────────────────────────────────
  // Opens the camera so the tailor sees themself before going live. Throws when
  // the camera or microphone is refused.
  Future<void> startPreview({bool frontCamera = true}) async {
    _camera = await LocalVideoTrack.createCameraTrack(CameraCaptureOptions(
      cameraPosition: frontCamera ? CameraPosition.front : CameraPosition.back,
    ));
    notifyListeners();
  }

  Future<void> flipCamera(bool frontCamera) async {
    await _camera?.setCameraPosition(frontCamera ? CameraPosition.front : CameraPosition.back);
    notifyListeners();
  }

  // Sends the camera and microphone into the stream.
  Future<void> publish(String streamId) async {
    final access = await _access(streamId);
    await _connect(access);
    if (_camera == null) await startPreview();
    await _room!.localParticipant!.publishVideoTrack(_camera!);
    await _room!.localParticipant!.setMicrophoneEnabled(true);
  }

  Future<void> setMuted(bool muted) async {
    await _room?.localParticipant?.setMicrophoneEnabled(!muted);
  }

  // ── Viewer ─────────────────────────────────────────────────────────────────
  Future<void> watch(String streamId) async => _connect(await _access(streamId));

  Future<void> _connect(({String url, String token}) access) async {
    final room = Room();
    room.addListener(notifyListeners);
    _room = room;
    try {
      await room.connect(access.url, access.token);
    } catch (_) {
      throw const ApiException(0, 'Could not connect to the live video. Check your internet connection and try again.');
    }
    notifyListeners();
  }

  // Stops the camera and leaves the stream.
  Future<void> close() async {
    _closed = true;
    final room = _room, camera = _camera;
    _room = null;
    _camera = null;
    try {
      await camera?.stop();
      await room?.disconnect();
      await room?.dispose();
    } catch (_) {
      // Leaving must always finish.
    }
  }

  @override
  void notifyListeners() {
    if (!_closed) super.notifyListeners();
  }
}

// Shows the picture of [video], or [placeholder] while there is none.
class LiveVideoView extends StatelessWidget {
  final LiveVideo video;
  final Widget placeholder;
  final bool mirror;
  const LiveVideoView({super.key, required this.video, required this.placeholder, this.mirror = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: video,
      builder: (context, _) {
        final track = video.track;
        if (track == null) return placeholder;
        return VideoTrackRenderer(
          track,
          fit: VideoViewFit.cover,
          mirrorMode: mirror ? VideoViewMirrorMode.mirror : VideoViewMirrorMode.off,
        );
      },
    );
  }
}
