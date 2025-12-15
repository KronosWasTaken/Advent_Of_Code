const std = @import("std");
inline fn solve(input: []const u8) struct { min: u32, max: u32 } {
    @setRuntimeSafety(false);
    var dist: [8][8]u16 = [_][8]u16{[_]u16{0} ** 8} ** 8;
    var city_hash: [8]u64 = [_]u64{0} ** 8;
    var city_count: u8 = 0;
    var i: usize = 0;
    while (i < input.len) {
        const start = i;
        while (i < input.len and input[i] > 13) : (i += 1) {}
        const line = input[start..i];
        i += @intFromBool(i < input.len and input[i] == '\r');
        i += @intFromBool(i < input.len and input[i] == '\n');
        if (line.len == 0) break;
        var to_pos: usize = 0;
        while (line[to_pos] != ' ') : (to_pos += 1) {}
        var eq_pos = to_pos + 4;
        while (line[eq_pos] != ' ') : (eq_pos += 1) {}
        const city_a = line[0..to_pos];
        const city_b = line[to_pos + 4 .. eq_pos];
        var d: u16 = 0;
        var j = eq_pos + 3;
        while (j < line.len) : (j += 1) d = d * 10 + (line[j] - '0');
        const hash_a = std.hash.Wyhash.hash(0, city_a);
        const hash_b = std.hash.Wyhash.hash(0, city_b);
        var idx_a: u8 = 255;
        var idx_b: u8 = 255;
        for (0..city_count) |k| {
            if (city_hash[k] == hash_a) idx_a = @intCast(k);
            if (city_hash[k] == hash_b) idx_b = @intCast(k);
        }
        if (idx_a == 255) {
            city_hash[city_count] = hash_a;
            idx_a = city_count;
            city_count += 1;
        }
        if (idx_b == 255) {
            city_hash[city_count] = hash_b;
            idx_b = city_count;
            city_count += 1;
        }
        dist[idx_a][idx_b] = d;
        dist[idx_b][idx_a] = d;
    }
    const n: usize = city_count;
    const full_mask: u16 = (@as(u16, 1) << @intCast(n)) - 1;
    var dp_min: [256][8]u16 = [_][8]u16{[_]u16{9999} ** 8} ** 256;
    var dp_max: [256][8]u16 = [_][8]u16{[_]u16{0} ** 8} ** 256;
    for (0..n) |city| {
        dp_min[@as(u16, 1) << @intCast(city)][city] = 0;
        dp_max[@as(u16, 1) << @intCast(city)][city] = 0;
    }
    var mask: u16 = 1;
    while (mask <= full_mask) : (mask += 1) {
        for (0..n) |curr| {
            if ((mask >> @intCast(curr)) & 1 == 0) continue;
            const min_curr = dp_min[mask][curr];
            if (min_curr == 9999) continue;
            const max_curr = dp_max[mask][curr];
            for (0..n) |next| {
                if ((mask >> @intCast(next)) & 1 == 1) continue;
                const new_mask = mask | (@as(u16, 1) << @intCast(next));
                const d = dist[curr][next];
                const new_min = min_curr + d;
                const new_max = max_curr + d;
                if (new_min < dp_min[new_mask][next]) dp_min[new_mask][next] = new_min;
                if (new_max > dp_max[new_mask][next]) dp_max[new_mask][next] = new_max;
            }
        }
    }
    var min_dist: u32 = 9999;
    var max_dist: u32 = 0;
    for (0..n) |city| {
        if (dp_min[full_mask][city] < min_dist) min_dist = dp_min[full_mask][city];
        if (dp_max[full_mask][city] > max_dist) max_dist = dp_max[full_mask][city];
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
