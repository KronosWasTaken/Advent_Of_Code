const std = @import("std");

const Result = struct { p1: u32, p2: u32 };

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var lines = std.ArrayList([]const u8){};
    var iter = std.mem.tokenizeScalar(u8, input, '\n');
    while (iter.next()) |line| {
        lines.append(allocator, line) catch unreachable;
    }
    
    std.mem.sort([]const u8, lines.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lessThan);
    
    var guards = std.AutoHashMap(u32, [60]u32).init(allocator);
    var current_guard: u32 = 0;
    var sleep_start: u32 = 0;
    
    for (lines.items) |line| {
        if (line.len >= 26 and line[19] == 'G') {
            var i: usize = 26;
            var n: u32 = 0;
            while (i < line.len and line[i] >= '0' and line[i] <= '9') {
                n = n * 10 + (line[i] - '0');
                i += 1;
            }
            current_guard = n;
        } else if (line.len >= 20 and line[19] == 'f') {
            sleep_start = (line[15] - '0') * 10 + (line[16] - '0');
        } else if (line.len >= 20 and line[19] == 'w') {
            const wake_minute = (line[15] - '0') * 10 + (line[16] - '0');
            const entry = guards.getOrPut(current_guard) catch unreachable;
            if (!entry.found_existing) {
                entry.value_ptr.* = [_]u32{0} ** 60;
            }
            for (sleep_start..wake_minute) |m| {
                entry.value_ptr.*[m] += 1;
            }
        }
    }
    
    var max_sleep: u32 = 0;
    var sleepy_guard: u32 = 0;
    
    var guard_iter = guards.iterator();
    while (guard_iter.next()) |entry| {
        var total: u32 = 0;
        for (entry.value_ptr.*) |count| {
            total += count;
        }
        if (total > max_sleep) {
            max_sleep = total;
            sleepy_guard = entry.key_ptr.*;
        }
    }
    
    const schedule = guards.get(sleepy_guard).?;
    var max_minute: u32 = 0;
    var max_count: u32 = 0;
    for (schedule, 0..) |count, m| {
        if (count > max_count) {
            max_count = count;
            max_minute = @intCast(m);
        }
    }
    const part1 = sleepy_guard * max_minute;
    
    var best_guard: u32 = 0;
    var best_minute: u32 = 0;
    var best_freq: u32 = 0;
    
    guard_iter = guards.iterator();
    while (guard_iter.next()) |entry| {
        for (entry.value_ptr.*, 0..) |count, m| {
            if (count > best_freq) {
                best_freq = count;
                best_guard = entry.key_ptr.*;
                best_minute = @intCast(m);
            }
        }
    }
    const part2 = best_guard * best_minute;
    
    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
