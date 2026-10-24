# Engineering Handoff

Read [CODEX_RESUME.md](CODEX_RESUME.md), [FEATURE_MATRIX.md](FEATURE_MATRIX.md),
[PRODUCTION_IMPLEMENTATION_LEDGER.md](PRODUCTION_IMPLEMENTATION_LEDGER.md) and
[LISTENING_PROJECTION.md](LISTENING_PROJECTION.md) before making changes.

Preserve `AudioTrackingService.kt` at `0a8be43`. No current physical G/telemetry
or production-readiness claim is supported. Keep confirmed route fixtures
distinct from real unknown-attribution observations. Do not re-enable the legacy
writer, promote fallback names/MACs to physical identity, infer a collector lease
from process lifetime or fabricate duration across collection gaps.

Continue the approved roadmap autonomously in bounded, tested checkpoints.
Update the feature matrix, ledger, resume and regression evidence with each
implementation. Keep private local checkpoints and unrelated work intact.
Publish only reviewed source/tests/configuration/public documentation to the
review branch, never raw logs/device data/research/signing keys/build outputs.

Never force-push or rewrite published history. Use `git revert` for auditable
rollback. Do not merge into `main` or publish a release without authorization.
