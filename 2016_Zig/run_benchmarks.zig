const std = @import("std");

pub fn main() !void {
    var total_time: f64 = 0;

    const days = [_][]const u8{
        "day01", "day02", "day03", "day04", "day05", "day06", "day07", "day08", "day09", "day10",
        "day11", "day12", "day13", "day14", "day15", "day16", "day17", "day18", "day19", "day20",
        "day21", "day22", "day23", "day24", "day25"
    };

    const allocator = std.heap.page_allocator;

    const historical_bests = try readPreviousBenchmarks(allocator);

    var file = try std.fs.cwd().createFile("benchmark.md", .{});
    defer file.close();
    try file.writeAll("# Advent of Code 2016 - Zig Benchmark Results\n\n");
    try file.writeAll("| Day | Time (μs) |\n");
    try file.writeAll("| :--- | :--- |\n");

    for (days, 0..) |day, i| {
        const day_num = i + 1;
        const exe_name = try std.fmt.allocPrint(allocator, "{s}.exe", .{day});

        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{day, exe_name});
        _ = std.fs.cwd().openFile(full_path, .{}) catch {
             const msg = try std.fmt.allocPrint(allocator, "| Day {d:0>2} | N/A (Executable not found) |\n", .{day_num});
             try file.writeAll(msg);
             continue;
        };

        var best_time: f64 = historical_bests[i];

        for (0..20) |_| {
            const result = try std.process.Child.run(.{
                .allocator = allocator,
                .argv = &[_][]const u8{exe_name},
                .cwd = day,
            });

            if (parseTime(result.stderr)) |t| {
                if (t < best_time) best_time = t;
            } else if (parseAverage(result.stderr)) |t| {
                 if (t < best_time) best_time = t;
            } else if (parseTime(result.stdout)) |t| {
                if (t < best_time) best_time = t;
            } else if (parseAverage(result.stdout)) |t| {
                 if (t < best_time) best_time = t;
            }
        }

        if (best_time != std.math.inf(f64)) {
            const msg = try std.fmt.allocPrint(allocator, "| Day {d:0>2} | {d:.2} μs |\n", .{day_num, best_time});
            try file.writeAll(msg);
            total_time += best_time;
        } else {
            const msg = try std.fmt.allocPrint(allocator, "| Day {d:0>2} | N/A (Parse failed) |\n", .{day_num});
            try file.writeAll(msg);
        }
        std.debug.print("Day {d:0>2}: {d:.2} us\n", .{day_num, best_time});
    }

    const total_msg = try std.fmt.allocPrint(allocator, "\n---\n\n### **Total:** {d:.2} μs ({d:.2} ms)\n", .{total_time, total_time / 1000.0});
    try file.writeAll(total_msg);
}

fn parseTime(output: []const u8) ?f64 {
    var it = std.mem.tokenizeAny(u8, output, "\n\r");
    while (it.next()) |line| {

        if (std.mem.indexOf(u8, line, "Time")) |idx| {

            var colon_idx = idx + 4;
            while (colon_idx < line.len and line[colon_idx] != ':') : (colon_idx += 1) {}
            if (colon_idx >= line.len) continue;

            var parts = std.mem.tokenizeScalar(u8, line[colon_idx+1..], ' ');
            if (parts.next()) |num_str| {

                var clean_num: [64]u8 = undefined;
                var clean_len: usize = 0;
                for (num_str) |c| {
                    if ((c >= '0' and c <= '9') or c == '.' or c == '-') {
                        clean_num[clean_len] = c;
                        clean_len += 1;
                        if (clean_len >= 64) break;
                    }
                }
                const val = std.fmt.parseFloat(f64, clean_num[0..clean_len]) catch {
                    continue;
                };
                return val;
            }
        }
    }
    return null;
}

fn parseAverage(output: []const u8) ?f64 {
    var it = std.mem.tokenizeAny(u8, output, "\n\r");
    while (it.next()) |line| {

        if (std.mem.indexOf(u8, line, "Average")) |idx| {

            var colon_idx = idx + 7;
            while (colon_idx < line.len and line[colon_idx] != ':') : (colon_idx += 1) {}
            if (colon_idx >= line.len) continue;

            var parts = std.mem.tokenizeScalar(u8, line[colon_idx+1..], ' ');
            if (parts.next()) |num_str| {

                var clean_num: [64]u8 = undefined;
                var clean_len: usize = 0;
                for (num_str) |c| {
                    if ((c >= '0' and c <= '9') or c == '.' or c == '-') {
                        clean_num[clean_len] = c;
                        clean_len += 1;
                        if (clean_len >= 64) break;
                    }
                }
                const val = std.fmt.parseFloat(f64, clean_num[0..clean_len]) catch {
                    continue;
                };
                return val;
            }
        }
    }
    return null;
}

fn readPreviousBenchmarks(allocator: std.mem.Allocator) ![25]f64 {
    var times: [25]f64 = undefined;
    for (&times) |*t| t.* = std.math.inf(f64);

    const file = std.fs.cwd().openFile("benchmark.md", .{}) catch return times;
    defer file.close();

    const stat = try file.stat();
    const content = try file.readToEndAlloc(allocator, stat.size);
    defer allocator.free(content);

    var it = std.mem.tokenizeAny(u8, content, "\n\r");
    while (it.next()) |line| {
        if (!std.mem.startsWith(u8, line, "| Day")) continue;

        var parts = std.mem.tokenizeScalar(u8, line, '|');
        _ = parts.next();
        const day_part = parts.next() orelse continue;
        const time_part = parts.next() orelse continue;

        const trimmed_day = std.mem.trim(u8, day_part, " ");
        if (!std.mem.startsWith(u8, trimmed_day, "Day ")) continue;
        const day_idx = (std.fmt.parseInt(usize, trimmed_day[4..], 10) catch continue) - 1;
        if (day_idx >= 25) continue;

        const trimmed_time = std.mem.trim(u8, time_part, " ");
        if (std.mem.indexOf(u8, trimmed_time, " μs")) |idx| {
            const num_str = trimmed_time[0..idx];
            var clean_buf: [64]u8 = undefined;
            var clean_len: usize = 0;
            for (num_str) |c| {
                if (c != ',' and clean_len < 64) {
                    clean_buf[clean_len] = c;
                    clean_len += 1;
                }
            }
            times[day_idx] = std.fmt.parseFloat(f64, clean_buf[0..clean_len]) catch continue;
        }
    }
    return times;
}
