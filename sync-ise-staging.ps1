[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$StagingRoot = 'C:\Users\nguyen hoang nhan\Downloads\fpga\sap2v2'
)

$workspaceRoot = Split-Path -Parent $PSCommandPath
& (Join-Path $workspaceRoot 'prepare-program.ps1')
if (!$?) { throw 'RAM image generation failed.' }
$projectFiles = @(
    'alu.v',
    'ax309_io.v',
    'ax309.ucf',
    'clock.v',
    'ctrl_rom.bin',
    'flags.v',
    'io_demo.ucf',
    'io_demo.xise',
    'io_demo_tb.v',
    'io_demo_top.v',
    'ir.v',
    'memory.v',
    'memory_tb.v',
    'keys_tb.v',
    'pc.v',
    'program.bin',
    'program_ise.mem',
    'prepare-program.ps1',
    'check-ise-build.ps1',
    'README_AX309.md',
    'SIMULATION_RESULTS.md',
    'THUYET_TRINH_SAP2.md',
    'ON_THI_VAN_DAP_SAP2.md',
    'register.v',
    'run-sim.ps1',
    'run-sim-ise.sh',
    'sap2v2.xise',
    'top.v',
    'top_tb.v',
    'trace_tb.v'
)

if (-not (Test-Path -LiteralPath $StagingRoot -PathType Container)) {
    throw "ISE staging directory does not exist: $StagingRoot"
}

foreach ($projectFile in $projectFiles) {
    $sourcePath = Join-Path $workspaceRoot $projectFile
    $destinationPath = Join-Path $StagingRoot $projectFile

    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Workspace project file is missing: $sourcePath"
    }

    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force

    $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
    $destinationHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash
    if ($sourceHash -ne $destinationHash) {
        throw "Verification failed after syncing: $projectFile"
    }

    Write-Host "Synced $projectFile"
}

Write-Host "ISE staging source is synchronized from $workspaceRoot to $StagingRoot."
