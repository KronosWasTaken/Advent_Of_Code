const std = @import("std");

inline fn solve(input: []const u8) struct { p1: i16, p2: i16 } {
    @setRuntimeSafety(false);
    var map = [_]u8{0xFF} ** 26;
    var cnt: u8 = 0;
    var hap: [8][8]i16 = [_][8]i16{[_]i16{0} ** 8} ** 8;

    var i: usize = 0;
    while (i < input.len) {
        if (input[i] < 'A' or input[i] > 'Z') {
            i += 1;
            continue;
        }
        const u_char = input[i];
        var u = map[u_char - 'A'];
        if (u == 0xFF) {
            u = cnt;
            map[u_char - 'A'] = cnt;
            cnt += 1;
        }

        while (input[i] != ' ') : (i += 1) {}
        i += 7; // skip ' ' and "would "
        const sign: i16 = if (input[i] == 'g') 1 else -1;
        while (input[i] < '0' or input[i] > '9') : (i += 1) {}
        var val: i16 = 0;
        while (input[i] >= '0' and input[i] <= '9') : (i += 1) {
            val = val * 10 + @as(i16, input[i] - '0');
        }

        while (input[i] != '.') : (i += 1) {}
        var v_end = i;
        while (input[v_end - 1] != ' ') : (v_end -= 1) {}
        const v_char = input[v_end];
        var v = map[v_char - 'A'];
        if (v == 0xFF) {
            v = cnt;
            map[v_char - 'A'] = cnt;
            cnt += 1;
        }

        hap[u][v] += sign * val;
        hap[v][u] += sign * val;
        while (i < input.len and input[i] != '\n') : (i += 1) {}
    }

    // Held-Karp over subsets, one 8-lane vector per subset: lane k is the best path through
    // exactly that subset ending at person k (-inf where k is not in it). Extending to k is one
    // vector add of "happiness into k" and a horizontal max, with no data-dependent branches.
    // `free` lets the path start anywhere; `fixed` starts at person 0. Part 1 closes the fixed
    // path back to person 0 (a seating is a cycle, so its start is arbitrary). Part 2 seats you
    // between two neighbours, which just cuts the cycle: the best path with free ends.
    const V8 = @Vector(8, i16);
    const ninf: i16 = -16000;
    const lane_bits = @Vector(8, u8){ 1, 2, 4, 8, 16, 32, 64, 128 };
    var into: [8]V8 = undefined; // into[k][m] = happiness of edge m-k
    for (0..8) |k| {
        for (0..8) |m| into[k][m] = hap[m][k];
    }
    var free: [256]V8 = undefined;
    var fixed: [256]V8 = undefined;
    free[0] = @splat(ninf);
    fixed[0] = @splat(ninf);
    for (1..256) |set| {
        const in_set = (@as(@Vector(8, u8), @splat(@intCast(set))) & lane_bits) != @as(@Vector(8, u8), @splat(0));
        var f: V8 = undefined;
        var z: V8 = undefined;
        if (set & (set - 1) == 0) {
            // A single person: a path of length 0 that may only start at person 0 when fixed.
            f = @select(i16, in_set, @as(V8, @splat(0)), @as(V8, @splat(ninf)));
            z = if (set == 1) f else @splat(ninf);
        } else {
            inline for (0..8) |k| {
                // For k outside the set the lane is discarded below; reading the empty set
                // (index 0, all -inf) keeps it from touching rows not computed yet.
                const prev = (set ^ (@as(usize, 1) << k)) & (@as(usize, 0) -% ((set >> k) & 1));
                f[k] = @reduce(.Max, free[prev] + into[k]);
                z[k] = @reduce(.Max, fixed[prev] + into[k]);
            }
            f = @select(i16, in_set, f, @as(V8, @splat(ninf)));
            z = @select(i16, in_set, z, @as(V8, @splat(ninf)));
        }
        free[set] = f;
        fixed[set] = z;
    }

    const p1 = @reduce(.Max, fixed[(@as(usize, 1) << @intCast(cnt)) - 1] + into[0]);
    const p2 = @reduce(.Max, free[(@as(usize, 1) << @intCast(cnt)) - 1]);
    return .{ .p1 = p1, .p2 = p2 };
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
