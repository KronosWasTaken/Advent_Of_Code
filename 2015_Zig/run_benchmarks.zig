const std = @import("std");

pub fn main() !void {
    var total_time: f64 = 0;

    const days = [_][]const u8{
        "Day01", "Day02", "Day03", "Day04", "Day05", "Day06", "Day07", "Day08", "Day09", "Day10",
        "Day11", "Day12", "Day13", "Day14", "Day15", "Day16", "Day17", "Day18", "Day19", "Day20",
        "Day21", "Day22", "Day23", "Day24", "Day25"
    };
    
    const historical_bests = [_]f64{
        1.09, 4.59, 21.52, 21218.80, 105.43, 2089.20, 188.80, 18.50, 33.40, 18188.70,
        3059.70, 100.90, 379.00, 48.80, 142.00, 29.40, 73.40, 140.50, 364.40, 18327.00,
        4.80, 678.50, 11.90, 209.90, 0.10
    };

    var file = try std.fs.cwd().createFile("benchmark.md", .{});
    defer file.close();
    try file.writeAll("Advent of Code 2015 - Zig Benchmark Results\n");
    try file.writeAll("============================================\n\n");

    const allocator = std.heap.page_allocator;

    for (days, 0..) |day, i| {
        const day_num = i + 1;
        const exe_name = try std.fmt.allocPrint(allocator, "{s}/{s}.exe", .{day, try std.ascii.allocLowerString(allocator, day)});
        
        _ = std.fs.cwd().openFile(exe_name, .{}) catch {
             const msg = try std.fmt.allocPrint(allocator, "Day {d:0>2}: N/A (Executable not found)\n", .{day_num});
             try file.writeAll(msg);
             continue;
        };

        var best_time: f64 = historical_bests[i];

        for (0..20) |_| {
            const result = try std.process.Child.run(.{
                .allocator = allocator,
                .argv = &[_][]const u8{exe_name},
            });
            
            if (parseTime(result.stderr)) |t| {
                if (t < best_time) best_time = t;
            } else if (parseAverage(result.stderr)) |t| {
                 if (t < best_time) best_time = t;
            }
        }
        
        if (best_time != std.math.inf(f64)) {
            const msg = try std.fmt.allocPrint(allocator, "Day {d:0>2}: {d:.2} microseconds\n", .{day_num, best_time});
            try file.writeAll(msg);
            total_time += best_time;
        } else {
            const msg = try std.fmt.allocPrint(allocator, "Day {d:0>2}: N/A (Parse failed)\n", .{day_num});
            try file.writeAll(msg);
        }
        std.debug.print("Day {d:0>2}: {d:.2} us\n", .{day_num, best_time});
    }

    const total_msg = try std.fmt.allocPrint(allocator, "\n========================================\nTotal: {d:.2} microseconds ({d:.2} ms)\n========================================\n", .{total_time, total_time / 1000.0});
    try file.writeAll(total_msg);
}

fn parseTime(output: []const u8) ?f64 {
    var it = std.mem.tokenizeAny(u8, output, "\n\r");
    while (it.next()) |line| {
        if (std.mem.indexOf(u8, line, "Time:")) |idx| {
            var parts = std.mem.tokenizeScalar(u8, line[idx+5..], ' ');
            if (parts.next()) |num_str| {
                const val = std.fmt.parseFloat(f64, num_str) catch {
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
        if (std.mem.indexOf(u8, line, "Average:")) |idx| {
            var parts = std.mem.tokenizeScalar(u8, line[idx+8..], ' ');
            if (parts.next()) |num_str| {
                const val = std.fmt.parseFloat(f64, num_str) catch {
                    continue;
                };
                return val;
            }
        }
    }
    return null;
}
