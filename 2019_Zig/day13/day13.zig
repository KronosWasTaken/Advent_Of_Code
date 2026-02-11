const std = @import("std");

const Result = struct {
    p1: i64,
    p2: i64,
};

const State = enum {
    Running,
    Input,
    Output,
    Halted,
};

const Computer = struct {
    code: []i64,
    pc: i64 = 0,
    relative_base: i64 = 0,
    input_queue: std.ArrayList(i64),
    last_output: i64 = 0,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, code: []i64) !Computer {
        var expanded_code = try allocator.alloc(i64, code.len + 100000);
        for (code, 0..) |val, i| {
            expanded_code[i] = val;
        }
        for (code.len..expanded_code.len) |i| {
            expanded_code[i] = 0;
        }

        const input_queue = try std.ArrayList(i64).initCapacity(allocator, 10);

        return Computer{
            .code = expanded_code,
            .input_queue = input_queue,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Computer) void {
        self.allocator.free(self.code);
        self.input_queue.deinit(self.allocator);
    }

    fn addInput(self: *Computer, value: i64) !void {
        try self.input_queue.append(self.allocator, value);
    }

    fn getMode(_: *const Computer, instruction: i64, param_index: i64) i64 {
        var modes = @divTrunc(instruction, 100);
        for (0..@intCast(param_index)) |_| {
            modes = @divTrunc(modes, 10);
        }
        return @mod(modes, 10);
    }

    fn getParam(self: *Computer, param_index: i64, for_write: bool) i64 {
        const instruction = self.code[@intCast(self.pc)];
        const mode = self.getMode(instruction, param_index);
        const param_addr = self.pc + param_index + 1;
        const param_value = self.code[@intCast(param_addr)];

        return switch (mode) {
            0 => if (for_write) param_value else self.code[@intCast(param_value)],
            1 => param_value,
            2 => if (for_write) self.relative_base + param_value else self.code[@intCast(self.relative_base + param_value)],
            else => unreachable,
        };
    }

    fn run(self: *Computer) !State {
        while (true) {
            const instruction = @mod(self.code[@intCast(self.pc)], 100);

            switch (instruction) {
                1 => {
                    const a = self.getParam(0, false);
                    const b = self.getParam(1, false);
                    const c = self.getParam(2, true);
                    self.code[@intCast(c)] = a + b;
                    self.pc += 4;
                },
                2 => {
                    const a = self.getParam(0, false);
                    const b = self.getParam(1, false);
                    const c = self.getParam(2, true);
                    self.code[@intCast(c)] = a * b;
                    self.pc += 4;
                },
                3 => {
                    if (self.input_queue.items.len == 0) {
                        return .Input;
                    }
                    const input_value = self.input_queue.orderedRemove(0);
                    const addr = self.getParam(0, true);
                    self.code[@intCast(addr)] = input_value;
                    self.pc += 2;
                },
                4 => {
                    const output = self.getParam(0, false);
                    self.last_output = output;
                    self.pc += 2;
                    return .Output;
                },
                5 => {
                    const cond = self.getParam(0, false);
                    const target = self.getParam(1, false);
                    self.pc = if (cond != 0) target else self.pc + 3;
                },
                6 => {
                    const cond = self.getParam(0, false);
                    const target = self.getParam(1, false);
                    self.pc = if (cond == 0) target else self.pc + 3;
                },
                7 => {
                    const a = self.getParam(0, false);
                    const b = self.getParam(1, false);
                    const c = self.getParam(2, true);
                    self.code[@intCast(c)] = if (a < b) 1 else 0;
                    self.pc += 4;
                },
                8 => {
                    const a = self.getParam(0, false);
                    const b = self.getParam(1, false);
                    const c = self.getParam(2, true);
                    self.code[@intCast(c)] = if (a == b) 1 else 0;
                    self.pc += 4;
                },
                9 => {
                    const a = self.getParam(0, false);
                    self.relative_base += a;
                    self.pc += 2;
                },
                99 => {
                    return .Halted;
                },
                else => return .Halted,
            }
        }
    }
};

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {

    var code: [5000]i64 = undefined;
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

    const code_list = code[0..code_len];


    var computer1 = try Computer.init(allocator, code_list);
    defer computer1.deinit();

    var part1: i64 = 0;

    while (true) {
        const state1 = try computer1.run();
        if (state1 == .Halted) break;

        const state2 = try computer1.run();
        if (state2 == .Halted) break;

        const state3 = try computer1.run();
        if (state3 == .Halted) break;
        const tile_id = computer1.last_output;

        if (tile_id == 2) part1 += 1;
    }


    var code2 = try allocator.dupe(i64, code_list);
    defer allocator.free(code2);
    code2[0] = 2;

    var computer2 = try Computer.init(allocator, code2);
    defer computer2.deinit();

    var part2: i64 = 0;
    var ball_x: i64 = 0;
    var paddle_x: i64 = 0;

    while (true) {
        const state1 = try computer2.run();
        if (state1 == .Halted) break;

        if (state1 == .Input) {
            const input_val: i64 = if (ball_x < paddle_x) -1 else if (ball_x > paddle_x) 1 else 0;
            try computer2.addInput(input_val);
            continue;
        }

        const x = computer2.last_output;

        const state2 = try computer2.run();
        if (state2 == .Halted) break;
        _ = computer2.last_output;

        const state3 = try computer2.run();
        if (state3 == .Halted) break;
        const tile_id = computer2.last_output;

        if (x == -1) {
            part2 = tile_id;
        } else if (tile_id == 3) {
            paddle_x = x;
        } else if (tile_id == 4) {
            ball_x = x;
        }
    }

    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;

    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
