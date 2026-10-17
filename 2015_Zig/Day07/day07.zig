const std = @import("std");

const Op = enum(u8) {
    constant,
    wire,
    not,
    bit,
    and_op,
    or_op,
    lshift,
    rshift,
};

const Gate = struct {
    op: Op,
    in1: u16,
    in2: u16,
};

inline fn wireId(s: []const u8) u16 {
    if (s.len == 1) return s[0] - 'a';
    return @as(u16, s[0] - 'a') * 26 + (s[1] - 'a') + 26;
}

inline fn parseNum(s: []const u8) u16 {
    var n: u16 = 0;
    for (s) |c| n = n * 10 + (c - '0');
    return n;
}


// The circuit and the signal cache live on the stack: on this machine first-touching stack
// pages is cheaper than first-touching fresh global (BSS) pages.
const Circuit = struct { gates: [729]Gate, cache: [729]u16 };

fn signal(cc: *Circuit, key: u16) u16 {
    if (cc.cache[key] != 0xFFFF) return cc.cache[key];
    const g = cc.gates[key];
    const res: u16 = switch (g.op) {
        .constant => g.in1,
        .wire => signal(cc, g.in1),
        .not => ~signal(cc, g.in1),
        .bit => 1 & signal(cc, g.in2),
        .and_op => signal(cc, g.in1) & signal(cc, g.in2),
        .or_op => signal(cc, g.in1) | signal(cc, g.in2),
        .lshift => signal(cc, g.in1) << @intCast(g.in2),
        .rshift => signal(cc, g.in1) >> @intCast(g.in2),
    };
    cc.cache[key] = res;
    return res;
}

inline fn parseWire(s: []const u8) u16 {
    if (s.len == 1) return s[0] - 'a';
    return @as(u16, s[0] - 'a') * 26 + (s[1] - 'a') + 26;
}

fn solve(input: []const u8) struct { p1: u16, p2: u16 } {
    @setRuntimeSafety(false);
    var cc: Circuit = undefined;
    const circuit = &cc.gates;
    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and (input[i] == ' ' or input[i] == '\r' or input[i] == '\n')) : (i += 1) {}
        if (i >= input.len) break;

        const tok1_start = i;
        while (i < input.len and input[i] > ' ') : (i += 1) {}
        const tok1 = input[tok1_start..i];

        while (i < input.len and input[i] == ' ') : (i += 1) {}
        const tok2_start = i;
        while (i < input.len and input[i] > ' ') : (i += 1) {}
        const tok2 = input[tok2_start..i];

        if (tok1[0] == 'N') { // NOT wire -> out
            while (i < input.len and input[i] != '>') : (i += 1) {}
            i += 2; // skip "> "
            const out_start = i;
            while (i < input.len and input[i] > ' ') : (i += 1) {}
            const out = parseWire(input[out_start..i]);
            circuit[out] = .{ .op = .not, .in1 = parseWire(tok2), .in2 = 0 };
        } else if (tok2[0] == '-') { // val/wire -> out
            i += 1; // skip " "
            const out_start = i;
            while (i < input.len and input[i] > ' ') : (i += 1) {}
            const out = parseWire(input[out_start..i]);
            if (tok1[0] >= '0' and tok1[0] <= '9') {
                circuit[out] = .{ .op = .constant, .in1 = parseNum(tok1), .in2 = 0 };
            } else {
                circuit[out] = .{ .op = .wire, .in1 = parseWire(tok1), .in2 = 0 };
            }
        } else { // tok1 OP tok3 -> out
            while (i < input.len and input[i] == ' ') : (i += 1) {}
            const tok3_start = i;
            while (i < input.len and input[i] > ' ') : (i += 1) {}
            const tok3 = input[tok3_start..i];

            while (i < input.len and input[i] != '>') : (i += 1) {}
            i += 2; // skip "> "
            const out_start = i;
            while (i < input.len and input[i] > ' ') : (i += 1) {}
            const out = parseWire(input[out_start..i]);

            switch (tok2[0]) {
                'A' => {
                    if (tok1[0] == '1') {
                        circuit[out] = .{ .op = .bit, .in1 = 0, .in2 = parseWire(tok3) };
                    } else {
                        circuit[out] = .{ .op = .and_op, .in1 = parseWire(tok1), .in2 = parseWire(tok3) };
                    }
                },
                'O' => {
                    circuit[out] = .{ .op = .or_op, .in1 = parseWire(tok1), .in2 = parseWire(tok3) };
                },
                'L' => {
                    circuit[out] = .{ .op = .lshift, .in1 = parseWire(tok1), .in2 = parseNum(tok3) };
                },
                'R' => {
                    circuit[out] = .{ .op = .rshift, .in1 = parseWire(tok1), .in2 = parseNum(tok3) };
                },
                else => unreachable,
            }
        }
    }

    const a_id = wireId("a");
    const b_id = wireId("b");

    @memset(&cc.cache, 0xFFFF);
    const p1 = signal(&cc, a_id);

    @memset(&cc.cache, 0xFFFF);
    cc.cache[b_id] = p1;
    const p2 = signal(&cc, a_id);

    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\nPart 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
