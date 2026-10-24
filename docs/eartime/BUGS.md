# Bugs And Open Limits

Updated 2026-10-24. Older local forensic reports are retained privately.

| Issue | Evidence | State |
| --- | --- | --- |
| Physical G immediate reopen/splash | Known-good reference `0a8be43`; ownership/startup model tests pass | Physical regression mechanism unproven; no current device PASS |
| B02 opening replaced by SYNC S | Native fixture T1=1000/S=5000/pause=9000 retains T1 and duration=8000 | Observed projection corrected; production liveness still gated |
| Output attribution | Protected collector reports global playback and fallback device claims | All real activity remains unverified, never confirmed listening |
| Collector liveness | Process can live after failed initialization or service recreation | Production extrapolation disabled; durable health/generation hook required |
| Physical identity | Legacy names/MAC fallbacks are not verified physical aliases | Provisional, epoch-scoped; normalization/association remains open |
| Experimental BLE | Inherited automatic discovery; no validated proprietary decoder | Do not claim opt-in operation or battery/wearing hardware support |
| Storage/performance | Indexed devices, bounded hints/results/work ceiling | Long-run profiling and cooperative replay fairness remain open |
| Data controls | Legacy data preserved read-only; OS backup excluded | Export/restore/deletion still incomplete |
| Release | Debug packaging and Kotlin debug/release compile pass | Authorized signing and physical acceptance required |

See [Feature Matrix](FEATURE_MATRIX.md) for the complete approved scope and
[Release Blockers](RELEASE_BLOCKERS.md) for acceptance requirements. No raw device
data or identifying failure logs are included in this public issue summary.
