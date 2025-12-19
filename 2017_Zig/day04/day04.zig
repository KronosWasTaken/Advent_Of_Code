const std = @import("std");
const Result = struct { p1: usize, p2: usize };
fn solve(input: []const u8) Result {
    var p1: usize = 0;
    var p2: usize = 0;
    var set1 = std.StringHashMap(void).init(std.heap.page_allocator);
    defer set1.deinit();
    var set2 = std.AutoHashMap([32]u8, void).init(std.heap.page_allocator);
    defer set2.deinit();
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        set1.clearRetainingCapacity();
        var valid1 = true;
        var tokens = std.mem.tokenizeAny(u8, line, " \t");
        while (tokens.next()) |token| {
            const result = set1.getOrPut(token) catch unreachable;
            if (result.found_existing) {
                valid1 = false;
            }
        }
        if (valid1) p1 += 1;
        set2.clearRetainingCapacity();
        var valid2 = true;
        tokens = std.mem.tokenizeAny(u8, line, " \t");
        while (tokens.next()) |token| {
            var freq = [_]u8{0} ** 32;
            for (token) |c| {
                if (c >= 'a' and c <= 'z') {
                    freq[c - 'a'] += 1;
                }
            }
            const result = set2.getOrPut(freq) catch unreachable;
            if (result.found_existing) {
                valid2 = false;
            }
        }
        if (valid2) p2 += 1;
    }
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
