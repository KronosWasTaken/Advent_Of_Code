const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
fn solve(input: []const u8) Result {
    var banks: std.ArrayList(u32) = .{};
    defer banks.deinit(std.heap.page_allocator);
    var tokens = std.mem.tokenizeAny(u8, input, " \t\n\r");
    while (tokens.next()) |token| {
        const num = std.fmt.parseInt(u32, token, 10) catch continue;
        banks.append(std.heap.page_allocator, num) catch unreachable;
    }
    var seen = std.AutoHashMap([16]u32, u32).init(std.heap.page_allocator);
    defer seen.deinit();
    var state: [16]u32 = undefined;
    @memcpy(state[0..banks.items.len], banks.items);
    var cycles: u32 = 0;
    seen.put(state, cycles) catch unreachable;
    while (true) {
        var max: u32 = 0;
        var max_idx: usize = 0;
        for (state[0..banks.items.len], 0..) |val, i| {
            if (val > max) {
                max = val;
                max_idx = i;
            }
        }
        state[max_idx] = 0;
        var idx = max_idx;
        var remaining = max;
        while (remaining > 0) : (remaining -= 1) {
            idx = (idx + 1) % banks.items.len;
            state[idx] += 1;
        }
        cycles += 1;
        if (seen.get(state)) |prev| {
            return .{ .p1 = cycles, .p2 = cycles - prev };
        }
        seen.put(state, cycles) catch unreachable;
    }
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
