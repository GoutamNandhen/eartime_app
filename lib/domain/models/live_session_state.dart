import 'audio_device.dart';
import 'connection_state.dart';
import 'playback_state.dart';

class LiveSessionState {
  final AudioDevice? activeDevice;
  final bool isInitialized;

  const LiveSessionState({
    this.activeDevice,
    this.isInitialized = false,
  });

  LiveSessionState copyWith({
    AudioDevice? activeDevice,
    bool? isInitialized,
  }) {
    return LiveSessionState(
      activeDevice: activeDevice ?? this.activeDevice,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  LiveSessionState withNoDevice() {
    return LiveSessionState(
      activeDevice: null,
      isInitialized: true,
    );
  }
}
