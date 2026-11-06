# k-Wave dependency

Official MATLAB toolbox v1.4.1, downloaded from https://www.k-wave.org/getfile.php?id=13 via https://www.k-wave.org/download.php on 2026-10-09.

Archive SHA256: `3c6a1232a9f930cc9679f648a228fbc6068de9b5972e0b9245134bbd92b445b9`.

Local path: `k-wave-1.4.1/k-wave-toolbox-version-1.4.1`. Upstream source is unchanged. Original GPL/LGPL texts are retained in its `license` folder. Archive/extracted toolbox are ignored by Git; this note documents how to reproduce the installation. No C++ binaries were downloaded. MATLAB implementation runs with gpuArray-single when available.

Do not recursively add this entire directory. The entry point adds only the toolbox root for its duration, then restores the previous MATLAB path.
