const std = @import("std");

inline fn solve(input: []const u8) struct { p1: u64, p2: u64 } {
    @setRuntimeSafety(false);
    var packages: [32]u32 = undefined;
    var count: usize = 0;
    var sum: usize = 0;

    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and (input[i] < '0' or input[i] > '9')) : (i += 1) {}
        if (i >= input.len) break;
        var num: u32 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            num = num * 10 + (input[i] - '0');
        }
        packages[count] = num;
        sum += num;
        count += 1;
    }

    const goal3 = sum / 3;
    const goal4 = sum / 4;

    var min_pkgs = [_]u32{std.math.maxInt(u32)} ** 600;
    var min_qe = [_]u64{std.math.maxInt(u64)} ** 600;
    min_pkgs[0] = 0;
    min_qe[0] = 1;

    for (packages[0..count]) |item| {
        var w: usize = goal3;
        while (w >= item) : (w -= 1) {
            const prev_pkgs = min_pkgs[w - item];
            if (prev_pkgs == std.math.maxInt(u32)) continue;
            const take = prev_pkgs + 1;
            const not_take = min_pkgs[w];
            const take_qe = @as(u64, item) *| min_qe[w - item];

            if (take < not_take) {
                min_pkgs[w] = take;
                min_qe[w] = take_qe;
            } else if (take == not_take) {
                if (take_qe < min_qe[w]) min_qe[w] = take_qe;
            }
        }
    }

    return .{ .p1 = min_qe[goal3], .p2 = min_qe[goal4] };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {d} | Part 2: {d}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
