# Advent of Code Solutions

Personal implementations of the [Advent of Code](https://adventofcode.com/) challenges, focusing on performance and minimalism.

## Repository Structure

The solutions are organized by year, primarily utilizing **Zig** for high-performance execution.

| Year | Primary Language | Directory |
| :--- | :--- | :--- |
| 2015 | Zig | `2015_Zig/` |
| 2016 | Zig | `2016_Zig/` |
| 2017 | Zig | `2017_Zig/` |
| 2018 | Zig | `2018_Zig/` |
| 2019 | Zig | `2019_Zig/` |
| 2020 | Zig | `2020_Zig/` |
| 2021 | Zig | `2021_Zig/` |
| 2022 | Zig | `2022_Zig/` |
| 2023 | Zig | `2023_Zig/` |
| 2024 | Zig | `2024_Zig/` |
| 2025 | Zig | `2025_Zig/` |

---

## Performance Metrics

The following table summarizes total execution times for all 25 days of each year. Detailed benchmarks for individual days are available in the `benchmark.md` files within each directory.

| Year | Execution Time (Total) | Benchmark Documentation |
| :--- | :--- | :--- |
| 2015 | 55.28 ms | [2015_Zig/benchmark.md](2015_Zig/benchmark.md) |
| 2016 | 135.84 ms | [2016_Zig/benchmark.md](2016_Zig/benchmark.md) |
| 2017 | 114.94 ms | [2017_Zig/benchmark.md](2017_Zig/benchmark.md) |
| 2018 | 92.86 ms | [2018_Zig/benchmark.md](2018_Zig/benchmark.md) |
| 2019 | 37.75 ms | [2019_Zig/benchmark.md](2019_Zig/benchmark.md) |
| 2020 | 422.21 ms | [2020_Zig/benchmark.md](2020_Zig/benchmark.md) |
| 2021 | 17.13 ms | [2021_Zig/benchmark.md](2021_Zig/benchmark.md) |
| 2022 | 7.86 ms | [2022_Zig/benchmark.md](2022_Zig/benchmark.md) |
| 2023 | 11.52 ms | [2023_Zig/benchmark.md](2023_Zig/benchmark.md) |
| 2024 | 21.59 ms | [2024_Zig/benchmark.md](2024_Zig/benchmark.md) |
| 2025 | 8.93 ms | [2025_Zig/benchmark.md](2025_Zig/benchmark.md) |
| **Total** | **925.92 ms (0.93 s)** | |

---

## Benchmark Environment

Benchmarks for 2015-2025 were collected on the following system:

- OS: Windows 25H2 (Build 26200.7840)
- CPU: AMD Ryzen 5 6600H with Radeon Graphics
- GPU: AMD RadeonT 660M; NVIDIA GeForce RTX 3050 Laptop GPU (4 GB VRAM)
- RAM: 16 GB
- Storage: Kingston SNV2S1000G SSD (1 TB), JMicron PCIe SSD (512 GB)
- Zig: 0.15.2

---

## Build and Execution Guide

### Zig Solutions
These solutions (2015-2025) were built with Zig `0.15.2`.

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

