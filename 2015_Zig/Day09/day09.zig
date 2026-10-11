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

    var table_min: [256][8]u16 = [_][8]u16{[_]u16{9999} ** 8} ** 256;
    var table_max: [256][8]u16 = [_][8]u16{[_]u16{0} ** 8} ** 256;

    for (0..8) |k| {
        table_min[@as(usize, 1) << @intCast(k)][k] = 0;
        table_max[@as(usize, 1) << @intCast(k)][k] = 0;
    }

    for (3..256) |set| {
        if (@popCount(set) < 2) continue;

        var k_bits = set;
        while (k_bits != 0) {
            const k = @ctz(k_bits);
            k_bits &= k_bits - 1;
            const subset = set ^ (@as(usize, 1) << @intCast(k));

            var shortest: u16 = 9999;
            var longest: u16 = 0;

            var m_bits = subset;
            while (m_bits != 0) {
                const m = @ctz(m_bits);
                m_bits &= m_bits - 1;
                const d = dist[m][k];
                const s = table_min[subset][m] + d;
                const l = table_max[subset][m] + d;
                if (s < shortest) shortest = s;
                if (l > longest) longest = l;
            }

            table_min[set][k] = shortest;
            table_max[set][k] = longest;
        }
    }

    var min_dist: u32 = 9999;
    var max_dist: u32 = 0;
    for (0..8) |k| {
        min_dist = @min(min_dist, table_min[255][k]);
        max_dist = @max(max_dist, table_max[255][k]);
    }

    return .{ .min = min_dist, .max = max_dist };
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
