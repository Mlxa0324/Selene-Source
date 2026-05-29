import 'package:flutter_test/flutter_test.dart';
import 'package:selene/widgets/player_settings_panel.dart';
import 'package:selene/widgets/video_player_surface.dart';
import 'package:selene/widgets/video_player_widget.dart';

void main() {
  test('video surface key stays stable when only fit type changes', () {
    final containKey = buildVideoSurfaceKey(
      surface: VideoPlayerSurface.desktop,
      adapterType: Object,
      fitType: VideoFitType.contain,
    );
    final fillKey = buildVideoSurfaceKey(
      surface: VideoPlayerSurface.desktop,
      adapterType: Object,
      fitType: VideoFitType.fill,
    );

    expect(fillKey, containKey);
  });
}
