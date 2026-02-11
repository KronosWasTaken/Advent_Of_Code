const std = @import("std");

const Result = struct {
    p1: i64,
    p2: i64,
};

const Computer = struct {
    code: std.ArrayList(i64),
    allocator: std.mem.Allocator,
    pc: i64 = 0,
    relative_base: i64 = 0,
    input_value: i64 = 0,
    last_output: i64 = 0,
    halted: bool = false,

    fn init(allocator: std.mem.Allocator, code_slice: []i64) !Computer {
        var code = try std.ArrayList(i64).initCapacity(allocator, code_slice.len + 10000);
        for (code_slice) |val| {
            try code.append(allocator, val);
        }

        for (0..10000) |_| {
            try code.append(allocator, 0);
        }
        return Computer{ .code = code, .allocator = allocator };
    }

    fn deinit(self: *Computer) void {
        self.code.deinit(self.allocator);
    }

    inline fn getParam(self: *Computer, param_index: i64, for_write: bool) i64 {
        const instruction = self.code.items[@intCast(self.pc)];
        var modes = @divTrunc(instruction, 100);
        for (0..@intCast(param_index)) |_| {
            modes = @divTrunc(modes, 10);
        }
        const mode = @mod(modes, 10);

        const param_addr = self.pc + param_index + 1;
        const param_value = self.code.items[@intCast(param_addr)];

        return switch (mode) {
            0 => if (for_write) param_value else self.code.items[@intCast(param_value)],
            1 => param_value,
            2 => if (for_write) self.relative_base + param_value else self.code.items[@intCast(self.relative_base + param_value)],
            else => unreachable,
        };
    }

    fn step(self: *Computer) void {
        if (self.halted) return;

        const instruction = @mod(self.code.items[@intCast(self.pc)], 100);

        switch (instruction) {
            1 => {
                const a = self.getParam(0, false);
                const b = self.getParam(1, false);
                const c = self.getParam(2, true);
                self.code.items[@intCast(c)] = a + b;
                self.pc += 4;
            },
            2 => {
                const a = self.getParam(0, false);
                const b = self.getParam(1, false);
                const c = self.getParam(2, true);
                self.code.items[@intCast(c)] = a * b;
                self.pc += 4;
            },
            3 => {
                const addr = self.getParam(0, true);
                self.code.items[@intCast(addr)] = self.input_value;
                self.pc += 2;
            },
            4 => {
                const output = self.getParam(0, false);
                self.last_output = output;
                self.pc += 2;
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
                self.code.items[@intCast(c)] = if (a < b) 1 else 0;
                self.pc += 4;
            },
            8 => {
                const a = self.getParam(0, false);
                const b = self.getParam(1, false);
                const c = self.getParam(2, true);
                self.code.items[@intCast(c)] = if (a == b) 1 else 0;
                self.pc += 4;
            },
            9 => {
                const a = self.getParam(0, false);
                self.relative_base += a;
                self.pc += 2;
            },
            99 => {
                self.halted = true;
            },
            else => {
                self.halted = true;
            },
        }
    }

    fn runUntilOutput(self: *Computer) void {
        while (!self.halted) {
            const instruction = @mod(self.code.items[@intCast(self.pc)], 100);
            if (instruction == 3 or instruction == 4) {

                return;
            }
            self.step();
        }
    }
};

fn move(computer: *Computer, dir: i64) i64 {

    computer.runUntilOutput();
    computer.input_value = dir + 1;
    computer.step();


    computer.runUntilOutput();
    computer.step();
    return computer.last_output;
}

fn solve(computer: *Computer, back: i64, o2dist: i64, allocator: std.mem.Allocator) !struct { i64, i64 } {
    var max_branch: i64 = 0;
    var max_spread: i64 = 0;
    var curr_o2dist: i64 = o2dist;

    var dir: i64 = 0;
    while (dir < 4) : (dir += 1) {

        if (dir == back) continue;

        const wall = move(computer, dir);
        if (wall == 0) continue;

        const o_status = move(computer, dir);


        const new_o2dist: i64 = if (o_status & 2 != 0) 2 else 0;
        const result = try solve(computer, dir ^ 1, new_o2dist, allocator);
        const o = result[0];
        const m = result[1];

        if (o > 0) {
            curr_o2dist = o + 2;
            max_spread = m;
        } else {
            max_branch = @max(max_branch, m + 2);
        }


        _ = move(computer, dir ^ 1);
        _ = move(computer, dir ^ 1);
    }

    return .{ curr_o2dist, @max(max_spread, curr_o2dist + max_branch) };
}

fn parseIntcode(input: []const u8, allocator: std.mem.Allocator) ![]i64 {
    var code = try std.ArrayList(i64).initCapacity(allocator, 1000);

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
                try code.append(allocator, if (negative) -num else num);
                num = 0;
                negative = false;
                in_number = false;
            }
        }
    }
    if (in_number) {
        try code.append(allocator, if (negative) -num else num);
    }

    return code.toOwnedSlice(allocator);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("input.txt");
    const code = try parseIntcode(input, allocator);
    defer allocator.free(code);

    var timer = try std.time.Timer.start();
    const start_time = timer.read();

    var computer = try Computer.init(allocator, code);
    defer computer.deinit();

    const result = try solve(&computer, -1, 0, allocator);
    const o2dist = result[0];
    const max_spread = result[1];

    const part1 = o2dist - 2;
    const part2 = max_spread - 2;

    const elapsed_ns = timer.read() - start_time;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;

    std.debug.print("Part 1: {}\n", .{part1});
    std.debug.print("Part 2: {}\n", .{part2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
