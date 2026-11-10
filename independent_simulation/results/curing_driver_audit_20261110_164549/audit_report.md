# Independent curing-driver export/readback audit

- Generated: 2026-11-10 16:45:50
- MATLAB: `24.1.0.3303086 (R2024a) Update 9`
- Repository: `F:\project\ICE`
- Scope: offline build/export + MAT readback only. No VSX, activate, simulator load, or hardware operation.
- Parameter status: probe dimensions and drive values are existing_code_unverified/assumed; acoustic output, temperature and cure remain unknown.

## Result: all checks passed

## Actual values (from reloaded MAT; timing rebuilt from Event/SeqControl)

| Variant | Elements | Ranks | Aperture mm | Arrival us | Max delay us | Events | TX | Pulses | Min interval us |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|
| All64 | 64 | 1:64 | 8.3000 | 13.256443 | 0.269361 | 363 | 300 | 300 | 1000.000 |
| Center48 | 48 | 9:56 | 6.2200 | 13.137650 | 0.150568 | 363 | 300 | 300 | 1000.000 |
| Center32 | 32 | 17:48 | 4.1400 | 13.052759 | 0.065678 | 363 | 300 | 300 | 1000.000 |
| Center16 | 16 | 25:40 | 2.0600 | 13.002436 | 0.015354 | 363 | 300 | 300 | 1000.000 |

## Checks

- Total: 461; passed: 461; failed: 0.
- Full records: `checks.csv`; readback values: `actual_values.csv`, `delay_table.csv`, `event_readback.csv`.

## Anomalies

- None in this run.

## Interpretation limits

- 300 pulses x 3.3333 us = 1 ms is a nominal envelope sum, not acoustic energy, temperature rise, or successful curing.
- Scheduled intervals are lower bounds derived from noop/TTNA values; hardware command overhead is unknown.
- The 6 MHz waveform differs from the 6.5 MHz probe reference used for delay computation; physical arrival is speed-of-sound based and was checked separately.
- A clean offline MAT does not demonstrate VSX loading, waveform quantization, output pressure, thermal limits, or probe safety.
