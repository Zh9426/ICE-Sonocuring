# Independent curing-driver export/readback audit

- Generated: 2026-11-10 16:36:53
- MATLAB: `24.1.0.3303086 (R2024a) Update 9`
- Repository: `F:\project\ICE`
- Scope: offline build/export + MAT readback only. No VSX, activate, simulator load, or hardware operation.
- Parameter status: probe dimensions and drive values are existing_code_unverified/assumed; acoustic output, temperature and cure remain unknown.

## Result: 5 of 5 checks FAILED

## Actual values (from reloaded MAT)

| Variant | Elements | Ranks | Aperture mm | Arrival us | Max delay us | Events | TX | Pulses | Min interval us |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|

## Checks

- Total: 5; passed: 0; failed: 5.
- Full records: `checks.csv`; readback values: `actual_values.csv`, `delay_table.csv`, `event_readback.csv`.

## Anomalies

- `All64/entry_build`: expected `success`, actual `未定义与 'double' 类型的输入参数相对应的函数 'range'。` (MATLAB:UndefinedFunction).
- `Center48/entry_build`: expected `success`, actual `未定义与 'double' 类型的输入参数相对应的函数 'range'。` (MATLAB:UndefinedFunction).
- `Center32/entry_build`: expected `success`, actual `未定义与 'double' 类型的输入参数相对应的函数 'range'。` (MATLAB:UndefinedFunction).
- `Center16/entry_build`: expected `success`, actual `未定义与 'double' 类型的输入参数相对应的函数 'range'。` (MATLAB:UndefinedFunction).
- `ALL/four_variants_completed`: expected `All64 | Center48 | Center32 | Center16`, actual `All64 | Center16 | Center32 | Center48` (All four documented entry points must build and export.).

## Interpretation limits

- 300 pulses x 3.3333 us = 1 ms is a nominal envelope sum, not acoustic energy, temperature rise, or successful curing.
- Scheduled intervals are lower bounds derived from noop/TTNA values; hardware command overhead is unknown.
- The 6 MHz waveform differs from the 6.5 MHz probe reference used for delay computation; physical arrival is speed-of-sound based and was checked separately.
- A clean offline MAT does not demonstrate VSX loading, waveform quantization, output pressure, thermal limits, or probe safety.
