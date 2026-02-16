const std = @import("std");

const Result = struct {
    p1: []const u8,
    p2: u64,
};

const Computer = struct {
    program: []const u64,
    a: u64,
    b: u64,
    c: u64,
    ip: usize,

    fn init(input: []const u64, a: u64) Computer {
        return .{ .program = input[3..], .a = a, .b = 0, .c = 0, .ip = 0 };
    }

    fn run(self: *Computer) ?u64 {
        while (self.ip < self.program.len) {
            const literal = self.program[self.ip + 1];
            const combo = switch (self.program[self.ip + 1]) {
                0, 1, 2, 3 => self.program[self.ip + 1],
                4 => self.a,
                5 => self.b,
                6 => self.c,
                else => unreachable,
            };
            const shift: u6 = @intCast(combo & 63);
            switch (self.program[self.ip]) {
                0 => self.a >>= shift,
                1 => self.b ^= literal,
                2 => self.b = combo % 8,
                3 => if (self.a != 0) {
                    self.ip = @intCast(literal);
                    continue;
                },
                4 => self.b ^= self.c,
                5 => {
                    const out = combo % 8;
                    self.ip += 2;
                    return out;
                },
                6 => self.b = self.a >> shift,
                7 => self.c = self.a >> shift,
                else => unreachable,
            }
            self.ip += 2;
        }
        return null;
    }
};

fn nextUnsigned(input: []const u8, index: *usize) ?u64 {
    var i = index.*;
    while (i < input.len and (input[i] < '0' or input[i] > '9')) : (i += 1) {}
    if (i >= input.len) {
        index.* = i;
        return null;
    }
    var value: u64 = 0;
    while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
        value = value * 10 + @as(u64, input[i] - '0');
    }
    index.* = i;
    return value;
}

fn helper(program: []const u64, index: usize, a: u64) ?u64 {
    if (index == 2) return a;
    var i: u64 = 0;
    while (i < 8) : (i += 1) {
        const next_a = (a << 3) | i;
        var computer = Computer.init(program, next_a);
        const out = computer.run() orelse continue;
        if (out == program[index]) {
            if (helper(program, index - 1, next_a)) |value| return value;
        }
    }
    return null;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var nums: std.ArrayListUnmanaged(u64) = .{};
    defer nums.deinit(allocator);

    var idx: usize = 0;
    while (nextUnsigned(input, &idx)) |value| {
        try nums.append(allocator, value);
    }

    var computer = Computer.init(nums.items, nums.items[0]);
    var out: std.ArrayListUnmanaged(u8) = .{};
    while (computer.run()) |n| {
        try out.append(allocator, @intCast(n + '0'));
        try out.append(allocator, ',');
    }
    if (out.items.len > 0) _ = out.pop();

    const p2 = helper(nums.items, nums.items.len - 1, 0) orelse 0;
    return .{ .p1 = out.items, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, std.heap.page_allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {s}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
