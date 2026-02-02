# Advent of Code Solutions

Personal implementations of the [Advent of Code](https://adventofcode.com/) challenges, focusing on performance and minimalism.

## Repository Structure

The solutions are organized by year, primarily utilizing **Zig** for high-performance execution, with select implementations in **JavaScript**.

| Year | Primary Language | Directory |
| :--- | :--- | :--- |
| 2015 | Zig | `2015_Zig/` |
| 2016 | Zig | `2016_Zig/` |
| 2017 | Zig | `2017_Zig/` |
| 2018 | Zig | `2018_Zig/` |
| 2019 | Zig (Days 1–25, excluding 7 & 17) / JavaScript (Days 7 & 17) | `2019_Zig_Js/` |
| 2020 | Zig | `2020_Zig/` |

---

## Performance Metrics

The following table summarizes total execution times for all 25 days of each year. Detailed benchmarks for individual days are available in the `benchmark.md` files within each directory.

| Year | Execution Time (Total) | Benchmark Documentation |
| :--- | :--- | :--- |
| 2015 | 65.31 ms | [`2015_Zig/benchmark.md`](2015_Zig/benchmark.md) |
| 2016 | 970.53 ms | [`2016_Zig/benchmark.md`](2016_Zig/benchmark.md) |
| 2017 | 233.96 ms | [`2017_Zig/benchmark.md`](2017_Zig/benchmark.md) |
| 2018 | 93.17 ms | [`2018_Zig/benchmark.md`](2018_Zig/benchmark.md) |
| 2019 | 170.14 ms | [`2019_Zig_Js/benchmark.md`](2019_Zig_Js/benchmark.md) |
| 2020 | 896.41 ms | [`2020_Zig/benchmark.md`](2020_Zig/benchmark.md) |
| **Total** | **2,429.52 ms (2.43 s)** | |

---

## Build and Execution Guide

### Zig Solutions
To compile and execute a Zig-based solution, navigate to the day's directory and run:

```bash
# Compile with ReleaseFast optimization
zig build-exe dayXX.zig -O ReleaseFast -fstrip

# Execute the binary
./dayXX.exe
```

> [!IMPORTANT]
> **2019 Day 12 Build Requirement**  
> Due to specific overflow safety requirements, Day 12 of 2019 must be compiled with `ReleaseSafe`:
> ```bash
> zig build-exe day12.zig -O ReleaseSafe -fstrip
> ```

### JavaScript Solutions
Days 7 and 17 of 2019 are implemented exclusively in JavaScript. These require [Node.js](https://nodejs.org/):

```bash
node dayXX.js
```
