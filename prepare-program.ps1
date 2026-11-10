[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$inputPath = Join-Path $PSScriptRoot 'program.bin'
$outputPath = Join-Path $PSScriptRoot 'program_ise.mem'
$tokens = @([regex]::Split(([IO.File]::ReadAllText($inputPath)).Trim(), '\s+'))
if ($tokens.Count -eq 0 -or $tokens.Count -gt 32768) {
    throw 'program.bin must contain 1..32768 bytes.'
}
$image = New-Object string[] 32768
for ($i = 0; $i -lt $image.Length; $i++) { $image[$i] = '00' }
for ($i = 0; $i -lt $tokens.Count; $i++) {
    if ($tokens[$i] -notmatch '^[0-9a-fA-F]{2}$') {
        throw "Invalid program byte at address ${i}: $($tokens[$i])"
    }
    $image[$i] = $tokens[$i].ToUpperInvariant()
}
# Generated build input: one complete RAM word per line, no BOM/comments.
[IO.File]::WriteAllLines($outputPath, $image, [Text.Encoding]::ASCII)
$check = [IO.File]::ReadAllLines($outputPath)
if ($check.Length -ne 32768) { throw 'Generated RAM image has incorrect depth.' }
for ($i = 0; $i -lt $image.Length; $i++) {
    if ($check[$i] -cne $image[$i]) { throw "RAM image verification failed at $i" }
}
Write-Host "Prepared program_ise.mem: $($tokens.Count) program bytes, 32768 RAM words."
