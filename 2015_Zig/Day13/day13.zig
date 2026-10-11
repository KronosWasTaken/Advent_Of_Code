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

    const Entry = struct { dist: i16, start: u8 };
    var table: [256][8]Entry = undefined;
    for (0..8) |k| {
        table[@as(usize, 1) << @as(u3, @intCast(k))][k] = .{ .dist = 0, .start = @as(u8, @intCast(k)) };
    }

    for (3..256) |set| {
        if ((set & (set - 1)) == 0) continue;

        var k_bits = set;
        while (k_bits != 0) {
            const k = @ctz(k_bits);
            k_bits &= k_bits - 1;

            const subset = set ^ (@as(usize, 1) << @as(u3, @intCast(k)));
            var longest: i16 = -30000;
            var start_node: u8 = 0;

            var m_bits = subset;
            while (m_bits != 0) {
                const m = @ctz(m_bits);
                m_bits &= m_bits - 1;

                const prior = table[subset][m];
                const d = prior.dist + hap[m][k];
                if (d > longest) {
                    longest = d;
                    start_node = prior.start;
                }
            }
            table[set][k] = .{ .dist = longest, .start = start_node };
        }
    }

    var p1: i16 = -30000;
    var p2: i16 = -30000;
    for (0..8) |k| {
        const entry = table[255][k];
        const loop_d = entry.dist + hap[entry.start][k];
        if (loop_d > p1) p1 = loop_d;
        if (entry.dist > p2) p2 = entry.dist;
    }

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
