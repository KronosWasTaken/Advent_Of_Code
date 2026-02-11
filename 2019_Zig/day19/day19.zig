const std = @import("std");

const Result = struct { p1: i64, p2: i64 };


const Computer = struct {
    V: [20000]i64 = undefined,
    i: usize = 0,
    r: i64 = 0,
    output: i64 = 0,
    inputs: [2]i64 = undefined,
    input_ptr: usize = 0,

    fn init(code: []const i64) Computer {
        var self: Computer = undefined;
        @memset(&self.V, 0);
        @memcpy(self.V[0..code.len], code);
        self.i = 0;
        self.r = 0;
        self.output = 0;
        self.input_ptr = 0;
        return self;
    }

    fn setInputs(self: *Computer, x: i64, y: i64) void {
        self.inputs[0] = x;
        self.inputs[1] = y;
        self.input_ptr = 0;
    }

    fn getParam(self: *Computer, mode: i64, idx: usize) i64 {
        const param = self.V[self.i + idx];
        return switch (mode) {
            0 => self.V[@intCast(param)],
            1 => param,
            2 => self.V[@intCast(self.r + param)],
            else => 0,
        };
    }

    fn setParam(self: *Computer, mode: i64, idx: usize, val: i64) void {
        const param = self.V[self.i + idx];
        const addr: usize = switch (mode) {
            0 => @intCast(param),
            2 => @intCast(self.r + param),
            else => @intCast(param),
        };
        self.V[addr] = val;
    }

    fn runToOutput(self: *Computer) bool {
        while (true) {
            const instr = self.V[self.i];
            const opcode = @mod(instr, 100);
            const m1 = @mod(@divFloor(instr, 100), 10);
            const m2 = @mod(@divFloor(instr, 1000), 10);
            const m3 = @mod(@divFloor(instr, 10000), 10);

            switch (opcode) {
                1 => {
                    const p1 = self.getParam(m1, 1);
                    const p2 = self.getParam(m2, 2);
                    self.setParam(m3, 3, p1 + p2);
                    self.i += 4;
                },
                2 => {
                    const p1 = self.getParam(m1, 1);
                    const p2 = self.getParam(m2, 2);
                    self.setParam(m3, 3, p1 * p2);
                    self.i += 4;
                },
                3 => {
                    if (self.input_ptr >= 2) return false;
                    self.setParam(m1, 1, self.inputs[self.input_ptr]);
                    self.input_ptr += 1;
                    self.i += 2;
                },
                4 => {
                    self.output = self.getParam(m1, 1);
                    self.i += 2;
                    return true;
                },
                5 => {
                    const p1 = self.getParam(m1, 1);
                    const p2 = self.getParam(m2, 2);
                    self.i = if (p1 != 0) @intCast(p2) else self.i + 3;
                },
                6 => {
                    const p1 = self.getParam(m1, 1);
                    const p2 = self.getParam(m2, 2);
                    self.i = if (p1 == 0) @intCast(p2) else self.i + 3;
                },
                7 => {
                    const p1 = self.getParam(m1, 1);
                    const p2 = self.getParam(m2, 2);
                    self.setParam(m3, 3, @intFromBool(p1 < p2));
                    self.i += 4;
                },
                8 => {
                    const p1 = self.getParam(m1, 1);
                    const p2 = self.getParam(m2, 2);
                    self.setParam(m3, 3, @intFromBool(p1 == p2));
                    self.i += 4;
                },
                9 => {
                    const p1 = self.getParam(m1, 1);
                    self.r += p1;
                    self.i += 2;
                },
                99 => return false,
                else => return false,
            }
        }
    }
};

fn parseIntcode(input: []const u8) [5000]i64 {
    var code: [5000]i64 = undefined;
    @memset(&code, 0);
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
    }

    return code;
}

fn test_point(code: *const [5000]i64, x: i64, y: i64) bool {
    var computer = Computer.init(code);
    computer.setInputs(x, y);
    _ = computer.runToOutput();
    return computer.output != 0;
}

fn solve(input: []const u8) Result {
    const code = parseIntcode(input);


    var part1: i64 = 0;
    var y: i64 = 0;
    while (y < 50) : (y += 1) {
        var x: i64 = 0;
        while (x < 50) : (x += 1) {
            if (test_point(&code, x, y)) {
                part1 += 1;
            }
        }
    }


    var px: i64 = 0;
    var py: i64 = 0;
    var moved = true;

    while (moved) {
        moved = false;


        while (!test_point(&code, px, py + 99)) {
            px += 1;
            moved = true;
        }


        while (!test_point(&code, px + 99, py)) {
            py += 1;
            moved = true;
        }
    }

    const part2 = 10000 * px + py;

    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");

    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0;
    std.debug.print("Part 1: {}\nPart 2: {}\nTime: {d:.2} ms\n", .{ result.p1, result.p2, elapsed_ms });
}
