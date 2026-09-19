param(
    [int]$Day = 0,
    [switch]$ForceRebuild
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$currentDir = Get-Location
$year = (Split-Path -Leaf $currentDir) -replace '_Zig', ''
$benchPath = Join-Path $currentDir "benchmark.md"

$mise = Get-Command mise -ErrorAction SilentlyContinue
$zig = if ($mise) { (& mise which zig 2>$null) } else { $null }
if (-not $zig) {
    $zig = (Get-Command zig -ErrorAction SilentlyContinue)?.Source
    if (-not $zig) { $zig = "zig" }
}

$existing = @{}
if (Test-Path $benchPath) {
    $content = [System.IO.File]::ReadAllText($benchPath, [System.Text.Encoding]::UTF8)
    foreach ($line in ($content -split "`r?`n")) {
        if ($line -match '^\|\s*Day\s*(\d{1,2})\s*\|\s*([0-9.,]+)\s*') {
            $d = [int]$Matches[1]
            $timeStr = $Matches[2] -replace ',', ''
            $val = 0.0
            if ([double]::TryParse($timeStr, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$val)) {
                $existing[$d] = $val
            }
        }
    }
}

$daysToRun = if ($Day -gt 0) { @($Day) } else { 1..25 }

function Get-DayInfo($d) {
    $d2 = "{0:d2}" -f $d
    $candidates = @("day$d2", "Day$d2")
    foreach ($c in $candidates) {
        $folderPath = Join-Path $currentDir $c
        if (Test-Path $folderPath) {
            $srcFiles = @(
                (Join-Path $folderPath "$c.zig"),
                (Join-Path $folderPath "day$d2.zig"),
                (Join-Path $folderPath "Day$d2.zig"),
                (Join-Path $folderPath "main.zig")
            )
            foreach ($src in $srcFiles) {
                if (Test-Path $src) {
                    $exe = Join-Path $folderPath "$c.exe"
                    return [PSCustomObject]@{
                        Folder  = $folderPath
                        SrcFile = $src
                        ExeFile = $exe
                    }
                }
            }
        }
    }
    return $null
}

function Parse-TimeMicroseconds($text) {
    if ($text -match '(?i)(?:Time|Average):\s*([0-9.]+)\s*(?:microseconds|microsecond|μs|us)') {
        return [double]$Matches[1]
    }
    if ($text -match '(?i)(?:Time|Average):\s*([0-9.]+)\s*ms') {
        return ([double]$Matches[1]) * 1000.0
    }
    if ($text -match '(?i)(?:Time|Average):\s*([0-9.]+)\s*ns') {
        return ([double]$Matches[1]) / 1000.0
    }
    if ($text -match '(?i)(?:Time|Average):\s*([0-9.]+)') {
        return [double]$Matches[1]
    }
    return $null
}

$results = @{}

foreach ($d in $daysToRun) {
    $info = Get-DayInfo $d
    if ($null -eq $info) {
        continue
    }

    $needsBuild = $ForceRebuild -or (-not (Test-Path $info.ExeFile))
    if (-not $needsBuild) {
        $srcTime = (Get-Item $info.SrcFile).LastWriteTimeUtc
        $exeTime = (Get-Item $info.ExeFile).LastWriteTimeUtc
        if ($srcTime -gt $exeTime) { $needsBuild = $true }
    }

    if ($needsBuild) {
        Write-Host "Compiling Day $d ($($info.SrcFile))..." -ForegroundColor Cyan
        $buildArgs = @("build-exe", "-O", "ReleaseFast", $info.SrcFile, "-femit-bin=$($info.ExeFile)")
        $buildProcess = Start-Process -FilePath $zig -ArgumentList $buildArgs -WorkingDirectory $info.Folder -NoNewWindow -Wait -PassThru
        if ($buildProcess.ExitCode -ne 0) {
            Write-Host "Error compiling Day ${d}" -ForegroundColor Red
            continue
        }
    }

    Push-Location $info.Folder
    $outText = (& $info.ExeFile 2>&1 | Out-String)
    Pop-Location

    $measured = Parse-TimeMicroseconds $outText

    if ($null -ne $measured -and $measured -ge 0) {
        $results[$d] = $measured
        $old = if ($existing.ContainsKey($d)) { $existing[$d] } else { $null }
        if ($null -ne $old) {
            if ($measured -lt $old) {
                Write-Host ("Day {0:d2}: UPGRADED! Old: {1:F2} μs -> New: {2:F2} μs (-{3:F2} μs)" -f $d, $old, $measured, ($old - $measured)) -ForegroundColor Green
            } else {
                Write-Host ("Day {0:d2}: Kept best {1:F2} μs (measured {2:F2} μs)" -f $d, $old, $measured) -ForegroundColor DarkGray
            }
        } else {
            Write-Host ("Day {0:d2}: Initial record {1:F2} μs" -f $d, $measured) -ForegroundColor Yellow
        }
    } else {
        Write-Host "Day ${d}: Could not parse execution time" -ForegroundColor Yellow
    }
}

$lines = @()
$lines += "# Advent of Code $year - Zig Benchmark Results"
$lines += ""
$lines += "| Day | Time (μs) |"
$lines += "| :--- | :--- |"
$total = 0.0

for ($d = 1; $d -le 25; $d++) {
    $best = $null
    if ($existing.ContainsKey($d)) {
        $best = $existing[$d]
    }
    if ($results.ContainsKey($d)) {
        $candidate = $results[$d]
        if ($null -eq $best -or $candidate -lt $best) {
            $best = $candidate
        }
    }

    if ($null -ne $best) {
        $total += $best
        $lines += "| Day {0:d2} | {1:F2} μs |" -f $d, $best
    } else {
        $lines += "| Day {0:d2} | N/A |" -f $d
    }
}

$lines += ""
$lines += "---"
$lines += ""
$lines += "### **Total:** {0:F2} μs ({1:F2} ms)" -f $total, ($total / 1000.0)

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($benchPath, ($lines -join "`n") + "`n", $utf8NoBom)

Write-Host "`n[$year Benchmark Updated] Total: $($total.ToString('F2')) μs ($(($total / 1000.0).ToString('F2')) ms)" -ForegroundColor Cyan
