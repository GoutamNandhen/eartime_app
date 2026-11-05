import '../models/audio_device.dart';
import '../models/connection_state.dart' as cs;
import '../models/live_session_state.dart';
import '../models/playback_state.dart' as ps;
import '../models/tracking_event.dart';

/// Event types that describe the listening timeline and are persisted to the database.
const persistedEventTypes = {
  'DEVICE_CONNECTED',
  'DEVICE_DISCONNECTED',
  'PLAYBACK_STARTED',
  'PLAYBACK_RESUMED',
  'PLAYBACK_PAUSED',
  'PLAYBACK_STOPPED',
};

const playbackStartTypes = {'PLAYBACK_STARTED', 'PLAYBACK_RESUMED'};
const playbackStopTypes = {'PLAYBACK_PAUSED', 'PLAYBACK_STOPPED'};

/// Pure state machine for the live (in-memory) session shown on Home.
///
/// Kept free of Riverpod/DB so every transition can be unit tested.
class LiveSessionReducer {
  const LiveSessionReducer._();

  /// The device a timeline event belongs to. Playback events without an id are attributed to
  /// the currently active device; when there is none they belong to nobody (speaker playback).
  static String? attributedDeviceId(LiveSessionState state, TrackingEvent event) {
    final id = event.resolvedDeviceId;
    if (id != null) return id;
    if (playbackStartTypes.contains(event.type) || playbackStopTypes.contains(event.type)) {
      return state.activeDevice?.canonicalDeviceId;
    }
    return null;
  }

  static LiveSessionState reduce(LiveSessionState state, TrackingEvent event) {
    final time = DateTime.fromMillisecondsSinceEpoch(event.timestamp);
    final active = state.activeDevice;

    switch (event.type) {
      case 'SYNC_STATE':
        return _sync(state, event, time);

      case 'DEVICE_CONNECTED':
        final id = event.resolvedDeviceId;
        if (id == null) return state;
        if (active != null && active.canonicalDeviceId == id) {
          // Duplicate connect for the device we already show: keep its playback state.
          return state.copyWith(isInitialized: true, activeDevice: active.copyWith(lastSeen: time));
        }
        return LiveSessionState(
          isInitialized: true,
          activeDevice: AudioDevice(
            canonicalDeviceId: id,
            displayName: _name(event.device),
            deviceType: _type(event.device),
            connectionState: cs.ConnectionState.connected,
            playbackState: ps.PlaybackState.stopped,
            lastSeen: time,
          ),
        );

      case 'DEVICE_DISCONNECTED':
        final id = event.resolvedDeviceId;
        if (active == null) return state.withNoDevice();
        if (id != null && id != active.canonicalDeviceId) {
          // Another (non-active) device left; the active one is unaffected.
          return state;
        }
        return state.withNoDevice();

      case 'PLAYBACK_STARTED':
      case 'PLAYBACK_RESUMED':
        final id = attributedDeviceId(state, event);
        if (id == null) return state;
        if (active != null &&
            active.canonicalDeviceId == id &&
            active.currentPlaybackStartTime != null) {
          return state; // Already playing; keep the original start time.
        }
        final base = (active != null && active.canonicalDeviceId == id)
            ? active
            : AudioDevice(
                canonicalDeviceId: id,
                displayName: _name(event.device),
                deviceType: _type(event.device),
                lastSeen: time,
              );
        return LiveSessionState(
          isInitialized: true,
          activeDevice: base.copyWith(
            connectionState: cs.ConnectionState.connected,
            playbackState: ps.PlaybackState.playing,
            lastSeen: time,
            currentPlaybackStartTime: time,
          ),
        );

      case 'PLAYBACK_PAUSED':
      case 'PLAYBACK_STOPPED':
        if (active == null) return state;
        final id = attributedDeviceId(state, event);
        if (id != active.canonicalDeviceId) return state;
        return LiveSessionState(
          isInitialized: true,
          activeDevice: active.copyWith(
            playbackState: event.type == 'PLAYBACK_PAUSED'
                ? ps.PlaybackState.paused
                : ps.PlaybackState.stopped,
            lastSeen: time,
            // Clearing the start time is what stops LiveTimerWidget (Bug B4/D/E).
            currentPlaybackStartTime: null,
          ),
        );

      default:
        return state;
    }
  }

  static LiveSessionState _sync(LiveSessionState state, TrackingEvent event, DateTime time) {
    if (event.connectedDevices.isEmpty) return state.withNoDevice();

    final wantedId = event.resolvedDeviceId;
    final device = event.connectedDevices.firstWhere(
      (d) => d['id'] == wantedId,
      orElse: () => event.connectedDevices.last,
    );
    final id = device['id'] as String?;
    if (id == null) return state.withNoDevice();

    final previous = state.activeDevice?.canonicalDeviceId == id ? state.activeDevice : null;
    final isPlaying = event.isPlaying ?? false;

    DateTime? start;
    if (isPlaying) {
      start = event.playbackStartedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(event.playbackStartedAt!)
          : previous?.currentPlaybackStartTime ?? time;
    }

    final ps.PlaybackState playbackState;
    if (isPlaying) {
      playbackState = ps.PlaybackState.playing;
    } else if (previous != null &&
        (previous.playbackState == ps.PlaybackState.playing ||
            previous.playbackState == ps.PlaybackState.paused)) {
      playbackState = ps.PlaybackState.paused;
    } else {
      playbackState = ps.PlaybackState.stopped;
    }

    return LiveSessionState(
      isInitialized: true,
      activeDevice: AudioDevice(
        canonicalDeviceId: id,
        displayName: _name(device),
        deviceType: _type(device),
        connectionState: cs.ConnectionState.connected,
        playbackState: playbackState,
        lastSeen: time,
        currentPlaybackStartTime: start,
      ),
    );
  }

  static String _name(Map<String, dynamic>? device) =>
      device?['friendlyName'] as String? ?? 'Unknown Device';

  static String _type(Map<String, dynamic>? device) =>
      device?['connectionType'] as String? ?? 'bluetooth';
}
