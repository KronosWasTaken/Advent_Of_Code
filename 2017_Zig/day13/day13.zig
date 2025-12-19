const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
fn gcd(a: u32, b: u32) u32 {
    var x = a;
    var y = b;
    while (y != 0) {
        const temp = y;
        y = x % y;
        x = temp;
    }
    return x;
}
fn lcm(a: u32, b: u32) u32 {
    return (a * b) / gcd(a, b);
}
fn solve(input: []const u8) Result {
    const gpa = std.heap.page_allocator;
    var layers: std.ArrayList([2]u32) = .{};
    defer layers.deinit(gpa);
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        var tokens = std.mem.tokenizeAny(u8, line, ": ");
        const depth = std.fmt.parseInt(u32, tokens.next() orelse continue, 10) catch continue;
        const range = std.fmt.parseInt(u32, tokens.next() orelse continue, 10) catch continue;
        layers.append(gpa, .{ depth, range }) catch unreachable;
    }
    std.mem.sort([2]u32, layers.items, {}, struct {
        fn lessThan(_: void, a: [2]u32, b: [2]u32) bool {
            return a[1] < b[1];
        }
    }.lessThan);
    var p1: u32 = 0;
    for (layers.items) |layer| {
        const depth = layer[0];
        const range = layer[1];
        const period = (range - 1) * 2;
        if (depth % period == 0) {
            p1 += depth * range;
        }
    }
    var current: std.ArrayList(u32) = .{};
    defer current.deinit(gpa);
    var next: std.ArrayList(u32) = .{};
    defer next.deinit(gpa);
    current.append(gpa, 1) catch unreachable;
    var current_lcm: u32 = 1;
    for (layers.items) |layer| {
        const depth = layer[0];
        const range = layer[1];
        const period = (range - 1) * 2;
        const next_lcm = lcm(current_lcm, period);
        var extra: u32 = 0;
        while (extra < next_lcm) : (extra += current_lcm) {
            for (current.items) |delay| {
                const test_delay = delay + extra;
                if ((test_delay + depth) % period != 0) {
                    next.append(gpa, test_delay) catch unreachable;
                }
            }
        }
        const temp = current;
        current = next;
        next = temp;
        next.clearRetainingCapacity();
        current_lcm = next_lcm;
    }
    const p2 = if (current.items.len > 0) current.items[0] else 0;
    return .{ .p1 = p1, .p2 = p2 };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var total: u64 = 0;
    const iterations = 1000;
    var result: Result = undefined;
    for (0..iterations) |_| {
        var timer = try std.time.Timer.start();
        result = solve(input);
        total += timer.read();
    }
    const avg_ns = total / iterations;
    const avg_us = @as(f64, @floatFromInt(avg_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{avg_us});
}