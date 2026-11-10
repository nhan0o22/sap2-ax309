[CmdletBinding()]
param(
    [string]$ToolRoot = (Join-Path $PSScriptRoot '.tools\iverilog\bin'),
    [switch]$Trace
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'prepare-program.ps1')
if (!$?) { throw 'RAM image generation failed.' }
$compiler = Join-Path $ToolRoot 'iverilog.exe'
$runtime = Join-Path $ToolRoot 'vvp.exe'
if (!(Test-Path -LiteralPath $compiler) -or !(Test-Path -LiteralPath $runtime)) {
    throw 'Set -ToolRoot to the directory containing iverilog.exe and vvp.exe.'
}
$cpuSources = @('top_tb.v','top.v','ax309_io.v','memory.v','register.v','pc.v','flags.v','alu.v')
$tests = @(
    @{Top='memory_tb'; Sources=@('memory_tb.v','memory.v')},
    @{Top='keys_tb'; Sources=@('keys_tb.v','ax309_io.v')},
    @{Top='io_demo_tb'; Sources=@('io_demo_tb.v','io_demo_top.v')},
    @{Top='top_tb'; Sources=$cpuSources}
)
if ($Trace) { $tests += @{Top='trace_tb'; Sources=(@('trace_tb.v') + $cpuSources)} }
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force 'sim-results' | Out-Null
    foreach ($test in $tests) {
        $output = Join-Path 'sim-results' ($test.Top + '.vvp')
        & $compiler -g2005 -s $test.Top -o $output @($test.Sources)
        if ($LASTEXITCODE -ne 0) { throw "Compile failed: $($test.Top)" }
        $log = @(& $runtime $output 2>&1)
        $code = $LASTEXITCODE
        $log | Set-Content -LiteralPath (Join-Path 'sim-results' ($test.Top + '.log'))
        $log | ForEach-Object { Write-Host $_ }
        if ($code -ne 0 -or ($log -match '^FAIL:') -or !($log -match '^PASS:')) {
            throw "Simulation failed: $($test.Top)"
        }
    }
    Write-Host 'PASS: all requested simulations'
} finally { Pop-Location }
