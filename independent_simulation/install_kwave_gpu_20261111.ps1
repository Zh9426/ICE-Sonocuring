param([string]$Destination = (Join-Path $PSScriptRoot 'dependencies/kwave-cuda-unified-v1.4.2'))
$ErrorActionPreference = 'Stop'
# Community k-Wave C++ release, not the MATLAB toolbox itself. SHA-256 values
# from GitHub's v1.4.2 expanded release assets, accessed 2026-11-11.
$assets = [ordered]@{
  'kspaceFirstOrder-CUDA-windows.exe'='806f20c2529c2454cef89badbfcc9c19c2360260236af5a4e98735a336899b09'
  'aec.dll'='45f80cf856f0bffe13137ca214026f61c03c3de4cfb4acbcc0f5b98ca285ce12'
  'concrt140.dll'='2405355f0a58067b258f8df33c327e3a3d716eaac5a3a5aebb757842d85bd376'
  'cudart64_13.dll'='58c509047f9dd1879cf82c6d5375a95c02c7bd295ae6c8362c745c936e2afc31'
  'hdf5.dll'='f49d2c8f3a691794580b9a60a84153b2e85b2d95b862610c80ea8c81b7b46e7d'
  'hdf5_hl.dll'='d567dbc5b5294ba213aeaf42623b48363f2159fc29ae440b07ebb48022362e2f'
  'msvcp140.dll'='0f885b509a685d2bbfa652fed26b5fb31d88fbdab0a978c641d1c7b8aa460aa9'
  'msvcp140_1.dll'='bfad5aef4c63a669e3c140655cdfdf395b6c979b400a447bd5dcb65ed8826c3d'
  'msvcp140_2.dll'='3ea06f0ee098b4823cb79599df3780e7f23cce52c19aac31d2a0d47efe33a5e9'
  'msvcp140_atomic_wait.dll'='640b2aefced484d0368eea5bdd06addd0658a3a70a49256e560d6923b404a479'
  'msvcp140_codecvt_ids.dll'='f2069a52880ec885ee7f0511186100eb7fada0411a2b4948fafea7735b878a18'
  'szip.dll'='260e00f5b76e2eacc2adad98f6ae38ef6dac15ae28b5185a3a209202a834ce6c'
  'vccorlib140.dll'='19839407c3fdbc824e5bce189bf68ddf8097f12ec28b757797ffa0415c144ddd'
  'vcomp140.dll'='95d4ce4a6802d1e18b5e0e1722cc30ea72ca7e033f83828f05c0b7b993fe7cbf'
  'vcruntime140.dll'='d5e4d9a3e835fa679450145d6a7d94e36573a509317111904d9b3712c30d9066'
  'vcruntime140_1.dll'='1f2d41c4aa5db0bc33ebf7b66d72943a817d7ce6cbe880502a9403823633093f'
  'vcruntime140_threads.dll'='219915cf20822f34d5e7c1fdd4e21ae7f3396881096c51036225fb8f84b47afa'
  'zlib1.dll'='a4cb496d64699161c03ec9ebaf2735e81472cf8fc17ebc289a2dc2aebc7e231b'
  'cufft64_12.dll'='611ba7e40dfab64b9b5bd35f4ad3593e00a8e93785fbf53160d9398aacd5ac14'
}
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
foreach ($entry in $assets.GetEnumerator()) {
  $filePath = Join-Path $Destination $entry.Key
  if (Test-Path -LiteralPath $filePath) {
    if ((Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.Value) {
      throw "Existing file has unexpected SHA-256; preserving: $filePath"
    }
    Write-Host "verified existing $($entry.Key)"
    continue
  }
  $partial = "$filePath.download"
  if (Test-Path -LiteralPath $partial) { throw "Existing partial file; inspect before resuming: $partial" }
  $url = "https://github.com/waltsims/kspacefirstorder-unified/releases/download/v1.4.2/$($entry.Key)"
  Write-Host "Downloading $($entry.Key)"
  # This Windows host cannot contact its certificate revocation endpoint.
  # TLS certificate/hostname verification remains enabled; release SHA-256
  # is checked before the downloaded file can be used.
  & curl.exe --ssl-no-revoke --fail --location --retry 2 --connect-timeout 20 --max-time 600 --silent --show-error --output $partial $url
  if ($LASTEXITCODE -ne 0) { throw "Download failed (exit $LASTEXITCODE): $url" }
  $actual = (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $entry.Value) { throw "SHA-256 mismatch; preserving $partial (got $actual)" }
  Move-Item -LiteralPath $partial -Destination $filePath
  Write-Host "verified $($entry.Key) $actual"
}
Write-Host "GPU solver files verified in $Destination"
