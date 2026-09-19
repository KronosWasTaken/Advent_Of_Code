param(
    [int]$Year = 0,
    [int]$Day = 0,
    [switch]$ForceRebuild,
    [switch]$SummaryOnly
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$rootDir = Get-Location

$years = 2015..2025
$yearsToRun = if ($Year -gt 0) { @($Year) } else { $years }

if (-not $SummaryOnly) {
    foreach ($y in $yearsToRun) {
        $yearDir = Join-Path $rootDir "${y}_Zig"
        $scriptPath = Join-Path $yearDir "benchmark.ps1"
        if (Test-Path $scriptPath) {
            Write-Host "`n========================================================" -ForegroundColor Cyan
            Write-Host " Running Benchmarks for Year $y" -ForegroundColor Cyan
            Write-Host "========================================================" -ForegroundColor Cyan
            
            Push-Location $yearDir
            try {
                $childArgs = @{ Day = $Day }
                if ($ForceRebuild) { $childArgs.ForceRebuild = $true }
                & ".\benchmark.ps1" @childArgs
            } finally {
                Pop-Location
            }
        }
    }
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host " ALL-YEARS AOC BENCHMARK SUMMARY (2015 - 2025)" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ("{0,-8} | {1,-14} | {2,-14}" -f "Year", "Time (μs)", "Time (ms)")
Write-Host ("-" * 44)

$yearTotals = @{}
$grandTotalUs = 0.0

foreach ($y in $years) {
    $benchPath = Join-Path $rootDir "${y}_Zig\benchmark.md"
    $totalUs = 0.0
    if (Test-Path $benchPath) {
        $content = [System.IO.File]::ReadAllText($benchPath, [System.Text.Encoding]::UTF8)
        if ($content -match '### \*\*Total:\*\*\s*([0-9.,]+)\s*μs') {
            $numStr = $Matches[1] -replace ',', ''
            $parsed = 0.0
            if ([double]::TryParse($numStr, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
                $totalUs = $parsed
            }
        }
    }
    $yearTotals[$y] = $totalUs
    $grandTotalUs += $totalUs
    Write-Host ("{0,-8} | {1,14:F2} | {2,14:F2}" -f $y, $totalUs, ($totalUs / 1000.0))
}

Write-Host ("-" * 44)
Write-Host ("{0,-8} | {1,14:F2} | {2,14:F2}" -f "TOTAL", $grandTotalUs, ($grandTotalUs / 1000.0)) -ForegroundColor Yellow
$grandSec = $grandTotalUs / 1000000.0
Write-Host ("Grand Total: {0:F2} ms ({1:F2} s)" -f ($grandTotalUs / 1000.0), $grandSec) -ForegroundColor Yellow

$readmePath = Join-Path $rootDir "README.md"
if (Test-Path $readmePath) {
    $readmeContent = [System.IO.File]::ReadAllText($readmePath, [System.Text.Encoding]::UTF8)
    
    $tableRegex = '(?s)\| Year \| Execution Time \(Total\) \| Benchmark Documentation \|.*?(?=\r?\n\r?\n---|\r?\n---)'
    
    $newTableLines = @(
        "| Year | Execution Time (Total) | Benchmark Documentation |",
        "| :--- | :--- | :--- |"
    )
    foreach ($y in $years) {
        $msVal = $yearTotals[$y] / 1000.0
        $newTableLines += "| {0} | {1:F2} ms | [`{0}_Zig/benchmark.md`]({0}_Zig/benchmark.md) |" -f $y, $msVal
    }
    $newTableLines += "| **Total** | **{0:F2} ms ({1:F2} s)** | |" -f ($grandTotalUs / 1000.0), $grandSec
    
    $newTable = $newTableLines -join "`n"
    $updatedReadme = [System.Text.RegularExpressions.Regex]::Replace($readmeContent, $tableRegex, $newTable)
    
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($readmePath, $updatedReadme, $utf8NoBom)
    Write-Host "`n[README.md Updated with Grand Total: $($grandTotalUs / 1000.0) ms]" -ForegroundColor Green
}
