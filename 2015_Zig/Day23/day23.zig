const std = @import("std");
const Op = union(enum) {
    hlf,
    tpl,
    inc_a,
    inc_b,
    jmp: i32,
    jie: i32,
    jio: i32,
};
fn execute(program: []const Op, initial_a: u64) u64 {
    @setRuntimeSafety(false);
    var a = initial_a;
    var b: u64 = 0;
    var pc: i32 = 0;
    while (pc >= 0 and pc < program.len) {
        switch (program[@intCast(pc)]) {
            .hlf => {
                a /= 2;
                pc += 1;
            },
            .tpl => {
                a *= 3;
                pc += 1;
            },
            .inc_a => {
                a += 1;
                pc += 1;
            },
            .inc_b => {
                b += 1;
                pc += 1;
            },
            .jmp => |offset| pc += offset,
            .jie => |offset| {
                if (a % 2 == 0) {
                    pc += offset;
                } else {
                    pc += 1;
                }
            },
            .jio => |offset| {
                if (a == 1) {
                    pc += offset;
                } else {
                    pc += 1;
                }
            },
        }
    }
    return b;
}
fn solve(input: []const u8) struct { p1: u64, p2: u64 } {
    @setRuntimeSafety(false);
    var program: [50]Op = undefined;
    var prog_len: usize = 0;
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        if (line.len < 3) continue;
        const instr = line[0..3];
        if (std.mem.eql(u8, instr, "hlf")) {
            program[prog_len] = .hlf;
        } else if (std.mem.eql(u8, instr, "tpl")) {
            program[prog_len] = .tpl;
        } else if (std.mem.eql(u8, instr, "inc")) {
            if (line[4] == 'a') {
                program[prog_len] = .inc_a;
            } else {
                program[prog_len] = .inc_b;
            }
        } else if (std.mem.eql(u8, instr, "jmp")) {
            const offset = parseOffset(line[4..]);
            program[prog_len] = .{ .jmp = offset };
        } else if (std.mem.eql(u8, instr, "jie")) {
            const offset = parseOffset(line[7..]);
            program[prog_len] = .{ .jie = offset };
        } else if (std.mem.eql(u8, instr, "jio")) {
            const offset = parseOffset(line[7..]);
            program[prog_len] = .{ .jio = offset };
        }
        prog_len += 1;
    }
    const p1 = execute(program[0..prog_len], 0);
    const p2 = execute(program[0..prog_len], 1);
    return .{ .p1 = p1, .p2 = p2 };
}
fn parseOffset(s: []const u8) i32 {
    var result: i32 = 0;
    var negative = false;
    var idx: usize = 0;
    if (s[0] == '+') {
        idx = 1;
    } else if (s[0] == '-') {
        negative = true;
        idx = 1;
    }
    while (idx < s.len) : (idx += 1) {
        if (s[idx] >= '0' and s[idx] <= '9') {
            result = result * 10 + (s[idx] - '0');
        }
    }
    return if (negative) -result else result;
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
