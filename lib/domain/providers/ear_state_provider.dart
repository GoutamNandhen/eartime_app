import 'dart:async';
import '../models/ear_state.dart';
import '../models/earbud_capabilities.dart';
import '../models/tracking_event.dart';

abstract class EarStateProvider {
  /// Analyzes the BLE discovery result to determine capabilities
  Future<EarbudCapabilities> detectCapabilities(Map<String, dynamic> bleDiscoveryResult);

  /// Analyzes incoming BLE notification packets to determine ear state
  void processNotification(TrackingEvent event);

  /// A stream of ear states deduced by this provider
  Stream<EarState> get earStateStream;

  void dispose();
}

class OpoV1Provider implements EarStateProvider {
  final _earStateController = StreamController<EarState>.broadcast();

  @override
  Stream<EarState> get earStateStream => _earStateController.stream;

  @override
  Future<EarbudCapabilities> detectCapabilities(Map<String, dynamic> bleDiscoveryResult) async {
    bool hasOpoService = false;
    bool hasOpoNotify = false;

    final services = bleDiscoveryResult['services'] as List<dynamic>?;
    if (services != null) {
      for (var service in services) {
        final sUuid = service['uuid']?.toString().toLowerCase() ?? '';
        if (sUuid.contains('0000079a-d102-11e1-9b23-00025b00a5a5')) {
          hasOpoService = true;
          final characteristics = service['characteristics'] as List<dynamic>?;
          if (characteristics != null) {
            for (var char in characteristics) {
              final cUuid = char['uuid']?.toString().toLowerCase() ?? '';
              if (cUuid.contains('0200079a-d102-11e1-9b23-00025b00a5a5')) {
                final props = char['properties'] as List<dynamic>?;
                if (props != null && props.contains('NOTIFY')) {
                  hasOpoNotify = true;
                }
              }
            }
          }
        }
      }
    }

    if (hasOpoService) {
      return EarbudCapabilities(
        bleAvailable: CapabilityStatus.supported,
        gattAvailable: CapabilityStatus.supported,
        leAudioAvailable: CapabilityStatus.unknown,
        pacsAvailable: CapabilityStatus.unknown,
        individualBudIdentity: CapabilityStatus.unknown,
        leftRightIdentity: CapabilityStatus.unknown,
        leftRightConnectionState: CapabilityStatus.unknown,
        inEarDetection: CapabilityStatus.unknown,
        perEarExposure: CapabilityStatus.unknown,
        providerName: hasOpoNotify ? 'OPOv1 (Notify)' : 'OPOv1',
      );
    }
    
    throw Exception("OPOv1 not found");
  }

  @override
  void processNotification(TrackingEvent event) {
    // Currently we just emit an unknown state since we haven't mapped the packets yet.
    // The raw packet handling logic is in the UI for diagnostic observation.
    _earStateController.add(EarState(
      earSide: EarSide.unknown,
      confidence: 'unknown',
      source: 'opov1',
      timestamp: DateTime.fromMillisecondsSinceEpoch(event.timestamp),
    ));
  }

  @override
  void dispose() {
    _earStateController.close();
  }
}

class LeAudioPacsProvider implements EarStateProvider {
  final _earStateController = StreamController<EarState>.broadcast();

  @override
  Stream<EarState> get earStateStream => _earStateController.stream;

  @override
  Future<EarbudCapabilities> detectCapabilities(Map<String, dynamic> bleDiscoveryResult) async {
    bool hasPacs = false;
    bool hasAudioLocation = false;

    final services = bleDiscoveryResult['services'] as List<dynamic>?;
    if (services != null) {
      for (var service in services) {
        final sUuid = service['uuid']?.toString().toLowerCase() ?? '';
        if (sUuid.contains('1850')) {
          hasPacs = true;
          final characteristics = service['characteristics'] as List<dynamic>?;
          if (characteristics != null) {
            for (var char in characteristics) {
              final cUuid = char['uuid']?.toString().toLowerCase() ?? '';
              if (cUuid.contains('2bca')) {
                hasAudioLocation = true;
              }
            }
          }
        }
      }
    }

    if (hasPacs) {
      return EarbudCapabilities(
        bleAvailable: CapabilityStatus.supported,
        gattAvailable: CapabilityStatus.supported,
        leAudioAvailable: CapabilityStatus.supported,
        pacsAvailable: CapabilityStatus.supported,
        individualBudIdentity: hasAudioLocation ? CapabilityStatus.supported : CapabilityStatus.unknown,
        leftRightIdentity: hasAudioLocation ? CapabilityStatus.supported : CapabilityStatus.unknown,
        leftRightConnectionState: CapabilityStatus.unknown, // PACS audio location doesn't mean connected
        inEarDetection: CapabilityStatus.unknown,
        perEarExposure: CapabilityStatus.unknown,
        providerName: 'LE Audio PACS',
      );
    }

    throw Exception("PACS not found");
  }

  @override
  void processNotification(TrackingEvent event) {
    // No-op for now.
  }

  @override
  void dispose() {
    _earStateController.close();
  }
}

class FallbackEarStateProvider implements EarStateProvider {
  final _earStateController = StreamController<EarState>.broadcast();

  @override
  Stream<EarState> get earStateStream => _earStateController.stream;

  @override
  Future<EarbudCapabilities> detectCapabilities(Map<String, dynamic> bleDiscoveryResult) async {
    return const EarbudCapabilities(
      bleAvailable: CapabilityStatus.unknown,
      gattAvailable: CapabilityStatus.unknown,
      leAudioAvailable: CapabilityStatus.unknown,
      pacsAvailable: CapabilityStatus.unknown,
      individualBudIdentity: CapabilityStatus.unknown,
      leftRightIdentity: CapabilityStatus.unknown,
      leftRightConnectionState: CapabilityStatus.unknown,
      inEarDetection: CapabilityStatus.unknown,
      perEarExposure: CapabilityStatus.unknown,
      providerName: 'Fallback',
    );
  }

  @override
  void processNotification(TrackingEvent event) {
    // Fallback has no per-ear insight
    _earStateController.add(EarState(
      earSide: EarSide.unknown,
      confidence: 'unknown',
      source: 'fallback',
      timestamp: DateTime.fromMillisecondsSinceEpoch(event.timestamp),
    ));
  }

  @override
  void dispose() {
    _earStateController.close();
  }
}
