const std = @import("std");

const EXTRA: usize = 3_000;

const Result = struct {
    p1: i64,
    p2: i64,
};

const State = union(enum) {
    Input,
    Output: i64,
    Halted,
};

const Computer = struct {
    pc: usize = 0,
    base: usize = 0,
    code: []usize,
    input_queue: std.ArrayListUnmanaged(usize) = .{},
    input_read_idx: usize = 0,
    allocator: std.mem.Allocator,

    const Self = @This();

    fn init(allocator: std.mem.Allocator, program: []const i64) Self {
        var code = allocator.alloc(usize, program.len + EXTRA) catch unreachable;
        for (program, 0..) |value, idx| {
            code[idx] = @as(usize, @intCast(value));
        }
        @memset(code[program.len..], 0);

        return Self{
            .pc = 0,
            .base = 0,
            .code = code,
            .input_queue = .{},
            .input_read_idx = 0,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        self.input_queue.deinit(self.allocator);
        self.allocator.free(self.code);
    }

    fn input(self: *Self, value: i64) void {
        self.input_queue.append(self.allocator, @as(usize, @intCast(value))) catch unreachable;
    }

    fn reset(self: *Self) void {
        self.pc = 0;
        self.base = 0;
        self.input_queue.clearRetainingCapacity();
        self.input_read_idx = 0;
    }

    fn popInput(self: *Self) ?usize {
        if (self.input_read_idx >= self.input_queue.items.len) {
            return null;
        }
        const value = self.input_queue.items[self.input_read_idx];
        self.input_read_idx += 1;
        if (self.input_read_idx == self.input_queue.items.len) {
            self.input_queue.clearRetainingCapacity();
            self.input_read_idx = 0;
        }
        return value;
    }

    fn run(self: *Self) State {
        while (true) {
            const op = self.code[self.pc];

            switch (op % 100) {
                1 => {
                    const first = self.address(op / 100, 1);
                    const second = self.address(op / 1000, 2);
                    const third = self.address(op / 10000, 3);
                    self.code[third] = self.code[first] +% self.code[second];
                    self.pc += 4;
                },
                2 => {
                    const first = self.address(op / 100, 1);
                    const second = self.address(op / 1000, 2);
                    const third = self.address(op / 10000, 3);
                    self.code[third] = self.code[first] *% self.code[second];
                    self.pc += 4;
                },
                3 => {
                    const value = self.popInput() orelse return .Input;
                    const first = self.address(op / 100, 1);
                    self.code[first] = value;
                    self.pc += 2;
                },
                4 => {
                    const first = self.address(op / 100, 1);
                    const value = self.code[first];
                    self.pc += 2;
                    return .{ .Output = @as(i64, @intCast(value)) };
                },
                5 => {
                    const first = self.address(op / 100, 1);
                    const second = self.address(op / 1000, 2);
                    const value = self.code[first] == 0;
                    self.pc = if (value) self.pc + 3 else self.code[second];
                },
                6 => {
                    const first = self.address(op / 100, 1);
                    const second = self.address(op / 1000, 2);
                    const value = self.code[first] == 0;
                    self.pc = if (value) self.code[second] else self.pc + 3;
                },
                7 => {
                    const first = self.address(op / 100, 1);
                    const second = self.address(op / 1000, 2);
                    const third = self.address(op / 10000, 3);
                    const value = @as(i64, @intCast(self.code[first])) < @as(i64, @intCast(self.code[second]));
                    self.code[third] = @as(usize, @intFromBool(value));
                    self.pc += 4;
                },
                8 => {
                    const first = self.address(op / 100, 1);
                    const second = self.address(op / 1000, 2);
                    const third = self.address(op / 10000, 3);
                    const value = self.code[first] == self.code[second];
                    self.code[third] = @as(usize, @intFromBool(value));
                    self.pc += 4;
                },
                9 => {
                    const first = self.address(op / 100, 1);
                    self.base = self.base +% self.code[first];
                    self.pc += 2;
                },
                else => return .Halted,
            }
        }
    }

    fn address(self: *Self, mode: usize, offset: usize) usize {
        const index = self.pc + offset;
        return switch (mode % 10) {
            0 => self.code[index],
            1 => index,
            2 => self.base +% self.code[index],
            else => unreachable,
        };
    }
};

fn parse(input: []const u8, allocator: std.mem.Allocator) !std.ArrayListUnmanaged(i64) {
    var numbers: std.ArrayListUnmanaged(i64) = .{};

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
                try numbers.append(allocator, if (negative) -num else num);
                num = 0;
                negative = false;
                in_number = false;
            }
        }
    }

    if (in_number) {
        try numbers.append(allocator, if (negative) -num else num);
    }

    return numbers;
}

fn permutations(values: []i64, start: usize, ctx: anytype) void {
    if (start + 1 >= values.len) {
        ctx.handle(values);
        return;
    }

    var i = start;
    while (i < values.len) : (i += 1) {
        std.mem.swap(i64, &values[start], &values[i]);
        permutations(values, start + 1, ctx);
        std.mem.swap(i64, &values[start], &values[i]);
    }
}

const Part1Context = struct {
    computer: *Computer,
    result: *i64,

    fn handle(self: *Part1Context, slice: []i64) void {
        var signal: i64 = 0;

        for (slice) |phase| {
            self.computer.reset();
            self.computer.input(phase);
            self.computer.input(signal);

            switch (self.computer.run()) {
                .Output => |next| signal = next,
                else => unreachable,
            }
        }

        if (signal > self.result.*) {
            self.result.* = signal;
        }
    }
};

const Part2Context = struct {
    computers: []Computer,
    result: *i64,

    fn handle(self: *Part2Context, slice: []i64) void {
        for (self.computers) |*computer| {
            computer.reset();
        }

        for (self.computers, slice) |*computer, phase| {
            computer.input(phase);
        }

        var signal: i64 = 0;

        outer: while (true) {
            for (self.computers) |*computer| {
                computer.input(signal);

                switch (computer.run()) {
                    .Output => |next| signal = next,
                    else => break :outer,
                }
            }
        }

        if (signal > self.result.*) {
            self.result.* = signal;
        }
    }
};

fn part1(input: []const i64, allocator: std.mem.Allocator) i64 {
    var result: i64 = 0;
    var computer = Computer.init(allocator, input);
    defer computer.deinit();

    var phases = [_]i64{ 0, 1, 2, 3, 4 };
    var ctx = Part1Context{ .computer = &computer, .result = &result };
    permutations(phases[0..], 0, &ctx);

    return result;
}

fn part2(input: []const i64, allocator: std.mem.Allocator) i64 {
    var result: i64 = 0;
    var computers: [5]Computer = undefined;
    for (0..5) |idx| {
        computers[idx] = Computer.init(allocator, input);
    }
    defer {
        for (0..5) |idx| {
            computers[idx].deinit();
        }
    }

    var phases = [_]i64{ 5, 6, 7, 8, 9 };
    var ctx = Part2Context{ .computers = computers[0..], .result = &result };
    permutations(phases[0..], 0, &ctx);

    return result;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var program = try parse(input, allocator);
    defer program.deinit(allocator);

    const p1 = part1(program.items, allocator);
    const p2 = part2(program.items, allocator);

    return Result{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
