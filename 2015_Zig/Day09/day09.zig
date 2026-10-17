const std = @import("std");
inline fn solve(input: []const u8) struct { min: u32, max: u32 } {
    @setRuntimeSafety(false);
    var dist: [8][8]u16 = [_][8]u16{[_]u16{0} ** 8} ** 8;
    var city_tags = [_]u16{0} ** 8;
    var city_count: u8 = 0;

    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and input[i] <= ' ') : (i += 1) {}
        if (i >= input.len) break;

        const tag_a: u16 = @as(u16, input[i]) | (@as(u16, input[i + 1]) << 8);
        while (i < input.len and input[i] != ' ') : (i += 1) {}
        i += 4; // skip " to "

        const tag_b: u16 = @as(u16, input[i]) | (@as(u16, input[i + 1]) << 8);
        while (i < input.len and input[i] != '=') : (i += 1) {}
        i += 2; // skip "= "

        var d: u16 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            d = d * 10 + (input[i] - '0');
        }

        var idx_a: usize = 8;
        var idx_b: usize = 8;
        for (0..city_count) |k| {
            if (city_tags[k] == tag_a) idx_a = k;
            if (city_tags[k] == tag_b) idx_b = k;
        }
        if (idx_a == 8) {
            city_tags[city_count] = tag_a;
            idx_a = city_count;
            city_count += 1;
        }
        if (idx_b == 8) {
            city_tags[city_count] = tag_b;
            idx_b = city_count;
            city_count += 1;
        }

        dist[idx_a][idx_b] = d;
        dist[idx_b][idx_a] = d;
    }

    // Held-Karp over subsets, one 8-lane vector per subset: lane k is the shortest (longest)
    // route through exactly that subset ending at city k, +inf (-inf) where k is not in it.
    // Extending to k is one vector add of "distance into k" and a horizontal min (max), with
    // no data-dependent branches.
    const V8 = @Vector(8, i16);
    const inf: i16 = 16000;
    const lane_bits = @Vector(8, u8){ 1, 2, 4, 8, 16, 32, 64, 128 };
    var into: [8]V8 = undefined; // into[k][m] = distance m-k
    for (0..8) |k| {
        for (0..8) |m| into[k][m] = @intCast(dist[m][k]);
    }
    var short: [256]V8 = undefined;
    var long: [256]V8 = undefined;
    short[0] = @splat(inf);
    long[0] = @splat(-inf);
    for (1..256) |set| {
        const in_set = (@as(@Vector(8, u8), @splat(@intCast(set))) & lane_bits) != @as(@Vector(8, u8), @splat(0));
        var s: V8 = @splat(0);
        var l: V8 = @splat(0);
        if (set & (set - 1) != 0) {
            inline for (0..8) |k| {
                // For k outside the set the lane is discarded below; reading the empty set
                // (index 0) keeps it from touching rows not computed yet.
                const prev = (set ^ (@as(usize, 1) << k)) & (@as(usize, 0) -% ((set >> k) & 1));
                s[k] = @reduce(.Min, short[prev] + into[k]);
                l[k] = @reduce(.Max, long[prev] + into[k]);
            }
        }
        short[set] = @select(i16, in_set, s, @as(V8, @splat(inf)));
        long[set] = @select(i16, in_set, l, @as(V8, @splat(-inf)));
    }

    const full = (@as(usize, 1) << @intCast(city_count)) - 1;
    return .{ .min = @intCast(@reduce(.Min, short[full])), .max = @intCast(@reduce(.Max, long[full])) };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\nPart 2: {}\n", .{ result.min, result.max });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
