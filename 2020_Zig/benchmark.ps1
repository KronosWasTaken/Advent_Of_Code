$days = 1..25
$results = @{}
foreach ($d in $days) {
  $day = "day{0:d2}" -f $d
  $exe = Join-Path $day "$day.exe"
  if (-not (Test-Path $exe)) { continue }
  $best = $null
  $output = & $exe 2>&1
  $line = $output | Where-Object { $_ -match 'Time: ([0-9.]+) microseconds' } | Select-Object -First 1
  if ($line -match 'Time: ([0-9.]+) microseconds') {
    $best = [double]$Matches[1]
  }
  if ($null -ne $best) { $results[$day] = $best }
}

$benchPath = "benchmark.md"
$existing = @{}
if (Test-Path $benchPath) {
  Get-Content $benchPath | ForEach-Object {
    if ($_ -match '^\| Day (\d{2}) \|\s*([0-9.]+)') {
      $existing["day$($Matches[1])"] = [double]$Matches[2]
    }
  }
}

$lines = @()
$lines += "# Advent of Code 2020 - Zig Benchmark Results"
$lines += ""
$lines += "| Day | Time (μs) |"
$lines += "| :--- | :--- |"
$total = 0.0
foreach ($d in $days) {
  $dayKey = "day{0:d2}" -f $d
  $best = $null
  if ($existing.ContainsKey($dayKey)) { $best = $existing[$dayKey] }
  if ($results.ContainsKey($dayKey)) {
    $candidate = $results[$dayKey]
    if ($null -eq $best -or $candidate -lt $best) { $best = $candidate }
  }
  if ($null -ne $best) { $total += $best }
  $timeText = if ($null -ne $best) { "{0:F2} μs" -f $best } else { "" }
  $lines += "| Day {0:d2} | {1} |" -f $d, $timeText
}
$lines += ""
$lines += "---"
$lines += ""
$lines += "### **Total:** {0:F2} μs ({1:F2} ms)" -f $total, ($total / 1000.0)
Set-Content $benchPath $lines