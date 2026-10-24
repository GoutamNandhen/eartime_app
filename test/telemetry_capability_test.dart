import 'package:eartime_app/domain/models/earbud_capabilities.dart';
import 'package:eartime_app/domain/providers/ear_state_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a service UUID does not prove per-ear identity, wearing or actual LE playback',
    () async {
      final provider = LeAudioPacsProvider();
      final result = await provider.detectCapabilities({
        'services': [
          {
            'uuid': '00001850-0000-1000-8000-00805f9b34fb',
            'characteristics': [
              {'uuid': '00002bca-0000-1000-8000-00805f9b34fb'},
            ],
          },
        ],
      });
      expect(result.pacsAvailable, CapabilityStatus.supported);
      expect(result.individualBudIdentity, CapabilityStatus.unknown);
      expect(result.leftRightIdentity, CapabilityStatus.unknown);
      expect(result.leAudioAvailable, CapabilityStatus.unknown);
      expect(result.inEarDetection, CapabilityStatus.unknown);
      provider.dispose();
    },
  );
  test(
    'substring UUID lookalikes cannot select a telemetry protocol',
    () async {
      final pacs = LeAudioPacsProvider();
      final opo = OpoV1Provider();
      await expectLater(
        pacs.detectCapabilities({
          'services': [
            {'uuid': 'fake1850'},
          ],
        }),
        throwsException,
      );
      await expectLater(
        opo.detectCapabilities({
          'services': [
            {'uuid': 'prefix0000079a-d102-11e1-9b23-00025b00a5a5suffix'},
          ],
        }),
        throwsException,
      );
      pacs.dispose();
      opo.dispose();
    },
  );
}
