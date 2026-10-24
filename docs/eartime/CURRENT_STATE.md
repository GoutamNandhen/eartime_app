# Current State

Updated 2026-10-24. The authoritative current documents are:

- [Resume Checkpoint](CODEX_RESUME.md)
- [Feature Matrix](FEATURE_MATRIX.md)
- [Implementation Ledger](PRODUCTION_IMPLEMENTATION_LEDGER.md)
- [Listening Projection](LISTENING_PROJECTION.md)
- [Release Blockers](RELEASE_BLOCKERS.md)

The product reads a native journal-backed projection. Legacy Drift data remain
preserved/read-only. Collector bytes match `0a8be43`; the full application has
changed, so physical G must not be inferred from source equality.

Current real output attribution is UNKNOWN. Production live extrapolation and
automatic listening reminders are disabled without a validated continuity lease.
The checkpoint is reviewable development progress, not RELEASE_READY. Raw logs,
device identifiers, APKs, research/decompiled material and signing secrets are
excluded from the public branch.
