[CmdletBinding()]
param([string]$BuildRoot = 'C:\Users\nguyen hoang nhan\Downloads\fpga\sap2v2')
$ErrorActionPreference = 'Stop'
$reportPath = Join-Path $BuildRoot 'top.syr'
$bitPath = Join-Path $BuildRoot 'top.bit'
foreach ($path in @($reportPath, $bitPath)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing build output: $path" }
}
$report = Get-Content -Raw -LiteralPath $reportPath
if ($report -match '(?m)^ERROR:' -or $report -notmatch 'Number of errors\s*:\s*0\s') {
    throw 'XST failed or did not finish. Do not program the existing top.bit.'
}
$bit = Get-Item -LiteralPath $bitPath
if ($bit.LastWriteTimeUtc -lt (Get-Item -LiteralPath $reportPath).LastWriteTimeUtc) {
    throw 'top.bit predates synthesis. Generate Programming File has not completed for this build.'
}
$inputs = Get-ChildItem -LiteralPath $BuildRoot -File | Where-Object {
    $_.Name -match '\.(v|ucf|xise|bin|mem)$' -and $_.Name -notmatch '_tb\.v$|^io_demo'
}
foreach ($inputFile in $inputs) {
    if ($inputFile.LastWriteTimeUtc -gt $bit.LastWriteTimeUtc) {
        throw "top.bit is older than source $($inputFile.Name). Rebuild before programming."
    }
}
Write-Host "PASS: XST completed and top.bit is newer than the build inputs: $($bit.LastWriteTime)"
Write-Host 'This checks output freshness, not the identity of the file selected in iMPACT.'
