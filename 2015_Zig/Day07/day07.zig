const std = @import("std");
inline fn wireId(s: []const u8) u16 {
    if (s.len == 1) return s[0] - 'a';
    return @as(u16, s[0] - 'a') * 26 + (s[1] - 'a') + 26;
}
inline fn parseNum(s: []const u8) u16 {
    var n: u16 = 0;
    for (s) |c| n = n * 10 + c - '0';
    return n;
}
const Gate = struct {
    op: u8,
    out: u16,
    in1: u16,
    in2: u16,
    is_lit1: bool,
    is_lit2: bool,
};
fn solve(input: []const u8, part2: bool, b_val: u16) u16 {
    @setRuntimeSafety(false);
    var gates: [350]Gate = undefined;
    var n: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        const start = i;
        while (i < input.len and input[i] != '\r' and input[i] != '\n') : (i += 1) {}
        const line = input[start..i];
        while (i < input.len and (input[i] == '\r' or input[i] == '\n')) : (i += 1) {}
        if (line.len == 0) break;
        var arrow: usize = 0;
        while (arrow < line.len - 1) : (arrow += 1) {
            if (line[arrow] == '-' and line[arrow + 1] == '>') break;
        }
        const out_str = line[arrow + 3 ..];
        const out = wireId(out_str);
        const expr = line[0..arrow - 1];
        if (part2 and out == wireId("b")) {
            gates[n] = .{ .op = 0, .out = out, .in1 = b_val, .in2 = 0, .is_lit1 = true, .is_lit2 = false };
            n += 1;
            continue;
        }
        var g: Gate = .{ .op = 0, .out = out, .in1 = 0, .in2 = 0, .is_lit1 = false, .is_lit2 = false };
        if (std.mem.indexOf(u8, expr, " AND ")) |p| {
            g.op = 2;
            const a = expr[0..p];
            if (a[0] >= '0' and a[0] <= '9') {
                g.in1 = parseNum(a);
                g.is_lit1 = true;
            } else {
                g.in1 = wireId(a);
            }
            g.in2 = wireId(expr[p + 5 ..]);
        } else if (std.mem.indexOf(u8, expr, " OR ")) |p| {
            g.op = 3;
            g.in1 = wireId(expr[0..p]);
            g.in2 = wireId(expr[p + 4 ..]);
        } else if (std.mem.indexOf(u8, expr, " LSHIFT ")) |p| {
            g.op = 5;
            g.in1 = wireId(expr[0..p]);
            g.in2 = parseNum(expr[p + 8 ..]);
            g.is_lit2 = true;
        } else if (std.mem.indexOf(u8, expr, " RSHIFT ")) |p| {
            g.op = 6;
            g.in1 = wireId(expr[0..p]);
            g.in2 = parseNum(expr[p + 8 ..]);
            g.is_lit2 = true;
        } else if (std.mem.startsWith(u8, expr, "NOT ")) {
            g.op = 4;
            g.in1 = wireId(expr[4..]);
        } else if (expr[0] >= '0' and expr[0] <= '9') {
            g.in1 = parseNum(expr);
            g.is_lit1 = true;
        } else {
            g.op = 1;
            g.in1 = wireId(expr);
        }
        gates[n] = g;
        n += 1;
    }
    var memo: [702]u16 = [_]u16{0xFFFF} ** 702;
    const target = wireId("a");
    while (memo[target] == 0xFFFF) {
        for (gates[0..n]) |g| {
            if (memo[g.out] != 0xFFFF) continue;
            const v1 = if (g.is_lit1) g.in1 else memo[g.in1];
            const v2 = if (g.is_lit2) g.in2 else memo[g.in2];
            if (g.op == 0 or g.op == 1) {
                if (v1 == 0xFFFF) continue;
                memo[g.out] = if (g.op == 0) g.in1 else v1;
            } else if (g.op == 4) {
                if (v1 == 0xFFFF) continue;
                memo[g.out] = ~v1;
            } else if (g.op == 5 or g.op == 6) {
                if (v1 == 0xFFFF) continue;
                memo[g.out] = if (g.op == 5) v1 << @intCast(g.in2) else v1 >> @intCast(g.in2);
            } else {
                if (v1 == 0xFFFF or v2 == 0xFFFF) continue;
                memo[g.out] = if (g.op == 2) v1 & v2 else v1 | v2;
            }
        }
    }
    return memo[target];
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const p1 = solve(input, false, 0);
    const p2 = solve(input, true, p1);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\nPart 2: {}\n", .{ p1, p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
