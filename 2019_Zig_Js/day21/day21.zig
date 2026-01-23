const std = @import("std");

const Result = struct { p1: i64, p2: i64 };

const Computer = struct {
    mem: [3000]i64,
    ip: usize,
    rel_base: i64,
    output: i64,

    fn init(code: []const i64) Computer {
        var self: Computer = undefined;
        @memset(&self.mem, 0);
        @memcpy(self.mem[0..code.len], code);
        self.ip = 0;
        self.rel_base = 0;
        self.output = 0;
        return self;
    }

    fn getParam(self: *Computer, mode: i64, offset: usize) i64 {
        const param = self.mem[self.ip + offset];
        return switch (mode) {
            0 => self.mem[@intCast(param)],
            1 => param,
            2 => self.mem[@intCast(self.rel_base + param)],
            else => 0,
        };
    }

    fn setParam(self: *Computer, mode: i64, offset: usize, val: i64) void {
        const param = self.mem[self.ip + offset];
        const addr: usize = switch (mode) {
            0 => @intCast(param),
            2 => @intCast(self.rel_base + param),
            else => @intCast(param),
        };
        self.mem[addr] = val;
    }

    const State = enum { NeedInput, Output, Halted };

    fn run(self: *Computer) State {
        while (true) {
            const instr = self.mem[self.ip];
            const op = @mod(instr, 100);
            const m1 = @mod(@divFloor(instr, 100), 10);
            const m2 = @mod(@divFloor(instr, 1000), 10);
            const m3 = @mod(@divFloor(instr, 10000), 10);

            switch (op) {
                1 => {
                    const a = self.getParam(m1, 1);
                    const b = self.getParam(m2, 2);
                    self.setParam(m3, 3, a + b);
                    self.ip += 4;
                },
                2 => {
                    const a = self.getParam(m1, 1);
                    const b = self.getParam(m2, 2);
                    self.setParam(m3, 3, a * b);
                    self.ip += 4;
                },
                3 => {
                    self.setParam(m1, 1, 0);
                    self.ip += 2;
                    return .NeedInput;
                },
                4 => {
                    self.output = self.getParam(m1, 1);
                    self.ip += 2;
                    return .Output;
                },
                5 => {
                    const a = self.getParam(m1, 1);
                    const b = self.getParam(m2, 2);
                    self.ip = if (a != 0) @intCast(b) else self.ip + 3;
                },
                6 => {
                    const a = self.getParam(m1, 1);
                    const b = self.getParam(m2, 2);
                    self.ip = if (a == 0) @intCast(b) else self.ip + 3;
                },
                7 => {
                    const a = self.getParam(m1, 1);
                    const b = self.getParam(m2, 2);
                    self.setParam(m3, 3, if (a < b) 1 else 0);
                    self.ip += 4;
                },
                8 => {
                    const a = self.getParam(m1, 1);
                    const b = self.getParam(m2, 2);
                    self.setParam(m3, 3, if (a == b) 1 else 0);
                    self.ip += 4;
                },
                9 => {
                    self.rel_base += self.getParam(m1, 1);
                    self.ip += 2;
                },
                99 => return .Halted,
                else => return .Halted,
            }
        }
    }

    fn provideInput(self: *Computer, val: i64) void {

        const last_instr = self.mem[self.ip - 2];
        const m1 = @mod(@divFloor(last_instr, 100), 10);
        const param = self.mem[self.ip - 1];
        const addr: usize = switch (m1) {
            0 => @intCast(param),
            2 => @intCast(self.rel_base + param),
            else => @intCast(param),
        };
        self.mem[addr] = val;
    }
};

fn parseIntcode(input: []const u8) [3000]i64 {
    var code: [3000]i64 = undefined;
    @memset(&code, 0);
    var idx: usize = 0;

    var num: i64 = 0;
    var neg = false;
    var in_num = false;

    for (input) |c| {
        if (c == '-') {
            neg = true;
            in_num = true;
        } else if (c >= '0' and c <= '9') {
            num = num * 10 + (c - '0');
            in_num = true;
        } else if (c == ',' or c == '\n') {
            if (in_num) {
                code[idx] = if (neg) -num else num;
                idx += 1;
                num = 0;
                neg = false;
                in_num = false;
            }
        }
    }
    if (in_num) {
        code[idx] = if (neg) -num else num;
    }

    return code;
}

fn runProgram(code: []const i64, program: []const u8) i64 {
    var computer = Computer.init(code);
    var prog_idx: usize = 0;

    while (true) {
        const state = computer.run();
        switch (state) {
            .NeedInput => {
                if (prog_idx < program.len) {
                    computer.provideInput(program[prog_idx]);
                    prog_idx += 1;
                } else {
                    break;
                }
            },
            .Output => {
                if (computer.output >= 128) {
                    return computer.output;
                }
            },
            .Halted => break,
        }
    }

    return computer.output;
}

fn solve(input: []const u8) Result {
    const code = parseIntcode(input);


    const p1_prog = "NOT C J\nNOT A T\nOR T J\nAND D J\nWALK\n";
    const part1 = runProgram(&code, p1_prog);


    const p2_prog = "OR B J\nAND C J\nNOT J J\nAND H J\nNOT A T\nOR T J\nAND D J\nRUN\n";
    const part2 = runProgram(&code, p2_prog);

    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");

    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\nPart 2: {}\nTime: {d:.2} microseconds\n", .{result.p1, result.p2, elapsed_us});
}
