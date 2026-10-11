const std = @import("std");

inline fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var items: [24]usize = undefined;
    var count: usize = 0;

    var idx: usize = 0;
    while (idx < input.len) {
        while (idx < input.len and (input[idx] < '0' or input[idx] > '9')) : (idx += 1) {}
        if (idx >= input.len) break;
        var val: usize = 0;
        while (idx < input.len and input[idx] >= '0' and input[idx] <= '9') : (idx += 1) {
            val = val * 10 + (input[idx] - '0');
        }
        items[count] = val;
        count += 1;
    }

    // Part 1: standard knapsack ways
    var ways1 = [_]u32{0} ** 151;
    ways1[0] = 1;

    // Part 2: minimum container restricted ways
    var ways2 = [_]u32{0} ** 151;
    var min_cnt = [_]u32{std.math.maxInt(u32)} ** 151;
    ways2[0] = 1;
    min_cnt[0] = 0;

    for (items[0..count]) |item| {
        var i: usize = 150;
        while (i >= item) : (i -= 1) {
            // Part 1
            ways1[i] += ways1[i - item];

            // Part 2
            const take = min_cnt[i - item] +| 1;
            const not_take = min_cnt[i];

            if (take < not_take) {
                ways2[i] = ways2[i - item];
                min_cnt[i] = take;
            } else if (take == not_take) {
                ways2[i] += ways2[i - item];
            }
        }
    }

    return .{ .p1 = ways1[150], .p2 = ways2[150] };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
