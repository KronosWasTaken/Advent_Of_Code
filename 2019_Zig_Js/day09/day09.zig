const std = @import("std");

const Result = struct {
    p1: i64,
    p2: i64,
};

const Computer = struct {
    code: []i64,
    pc: usize = 0,
    rb: i64 = 0,
    input_val: i64 = 0,

    fn run(self: *Computer) i64 {
        while (true) {
            const instr = self.code[self.pc];
            const op = @mod(instr, 100);
            const modes = @divTrunc(instr, 100);


            const m1_mode = @mod(modes, 10);
            const m2_mode = @mod(@divTrunc(modes, 10), 10);
            const m3_mode = @mod(@divTrunc(modes, 100), 10);

            const a = self.code[self.pc + 1];
            const b = self.code[self.pc + 2];
            const c = self.code[self.pc + 3];

            switch (op) {
                1 => {
                    const va = if (m1_mode == 0) self.code[@as(usize, @intCast(a))] else if (m1_mode == 1) a else self.code[@as(usize, @intCast(self.rb + a))];
                    const vb = if (m2_mode == 0) self.code[@as(usize, @intCast(b))] else if (m2_mode == 1) b else self.code[@as(usize, @intCast(self.rb + b))];
                    const addr = if (m3_mode == 0) @as(usize, @intCast(c)) else @as(usize, @intCast(self.rb + c));
                    self.code[addr] = va + vb;
                    self.pc += 4;
                },
                2 => {
                    const va = if (m1_mode == 0) self.code[@as(usize, @intCast(a))] else if (m1_mode == 1) a else self.code[@as(usize, @intCast(self.rb + a))];
                    const vb = if (m2_mode == 0) self.code[@as(usize, @intCast(b))] else if (m2_mode == 1) b else self.code[@as(usize, @intCast(self.rb + b))];
                    const addr = if (m3_mode == 0) @as(usize, @intCast(c)) else @as(usize, @intCast(self.rb + c));
                    self.code[addr] = va * vb;
                    self.pc += 4;
                },
                3 => {
                    const addr = if (m1_mode == 0) @as(usize, @intCast(a)) else @as(usize, @intCast(self.rb + a));
                    self.code[addr] = self.input_val;
                    self.pc += 2;
                },
                4 => {
                    const va = if (m1_mode == 0) self.code[@as(usize, @intCast(a))] else if (m1_mode == 1) a else self.code[@as(usize, @intCast(self.rb + a))];
                    self.pc += 2;
                    return va;
                },
                5 => {
                    const va = if (m1_mode == 0) self.code[@as(usize, @intCast(a))] else if (m1_mode == 1) a else self.code[@as(usize, @intCast(self.rb + a))];
                    const vb = if (m2_mode == 0) self.code[@as(usize, @intCast(b))] else if (m2_mode == 1) b else self.code[@as(usize, @intCast(self.rb + b))];
                    self.pc = if (va != 0) @as(usize, @intCast(vb)) else self.pc + 3;
                },
                6 => {
                    const va = if (m1_mode == 0) self.code[@as(usize, @intCast(a))] else if (m1_mode == 1) a else self.code[@as(usize, @intCast(self.rb + a))];
                    const vb = if (m2_mode == 0) self.code[@as(usize, @intCast(b))] else if (m2_mode == 1) b else self.code[@as(usize, @intCast(self.rb + b))];
                    self.pc = if (va == 0) @as(usize, @intCast(vb)) else self.pc + 3;
                },
                7 => {
                    const va = if (m1_mode == 0) self.code[@as(usize, @intCast(a))] else if (m1_mode == 1) a else self.code[@as(usize, @intCast(self.rb + a))];
                    const vb = if (m2_mode == 0) self.code[@as(usize, @intCast(b))] else if (m2_mode == 1) b else self.code[@as(usize, @intCast(self.rb + b))];
                    const addr = if (m3_mode == 0) @as(usize, @intCast(c)) else @as(usize, @intCast(self.rb + c));
                    self.code[addr] = if (va < vb) 1 else 0;
                    self.pc += 4;
                },
                8 => {
                    const va = if (m1_mode == 0) self.code[@as(usize, @intCast(a))] else if (m1_mode == 1) a else self.code[@as(usize, @intCast(self.rb + a))];
                    const vb = if (m2_mode == 0) self.code[@as(usize, @intCast(b))] else if (m2_mode == 1) b else self.code[@as(usize, @intCast(self.rb + b))];
                    const addr = if (m3_mode == 0) @as(usize, @intCast(c)) else @as(usize, @intCast(self.rb + c));
                    self.code[addr] = if (va == vb) 1 else 0;
                    self.pc += 4;
                },
                9 => {
                    const va = if (m1_mode == 0) self.code[@as(usize, @intCast(a))] else if (m1_mode == 1) a else self.code[@as(usize, @intCast(self.rb + a))];
                    self.rb += va;
                    self.pc += 2;
                },
                99 => return 0,
                else => unreachable,
            }
        }
    }
};

fn runProgram(code: []i64, input_val: i64) i64 {
    var computer = Computer{ .code = code, .input_val = input_val };
    var result: i64 = 0;
    while (computer.pc < code.len and computer.code[computer.pc] != 99) {
        result = computer.run();
    }
    return result;
}

fn solve(input: []const u8) Result {
    var code: [20000]i64 = undefined;
    @memset(code[0..], 0);
    var code_len: usize = 0;

    var num: i64 = 0;
    var negative = false;
    var in_number = false;

    for (input) |c| {
        if (c == '-') {
            negative = true;
            in_number = true;
        } else if (c >= '0' and c <= '9') {
            num = num * 10 + (c - '0');
            in_number = true;
        } else if (c == ',' or c == '\n' or c == '\r') {
            if (in_number) {
                code[code_len] = if (negative) -num else num;
                code_len += 1;
                num = 0;
                negative = false;
                in_number = false;
            }
        }
    }
    if (in_number) {
        code[code_len] = if (negative) -num else num;
        code_len += 1;
    }

    var code1: [20000]i64 = undefined;
    @memcpy(code1[0..code.len], code[0..]);
    const part1 = runProgram(code1[0..], 1);

    var code2: [20000]i64 = undefined;
    @memcpy(code2[0..code.len], code[0..]);
    const part2 = runProgram(code2[0..], 2);

    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}

