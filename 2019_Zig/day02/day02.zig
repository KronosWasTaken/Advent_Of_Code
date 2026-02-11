const std = @import("std");

const Result = struct {
    p1: i64,
    p2: i64,
};

inline fn execute(code: []i64, noun: i64, verb: i64) i64 {
    code[1] = noun;
    code[2] = verb;
    var pc: usize = 0;
    while (code[pc] != 99) : (pc += 4) {
        const opcode = code[pc];
        const a = @as(usize, @intCast(code[pc + 1]));
        const b = @as(usize, @intCast(code[pc + 2]));
        const c = @as(usize, @intCast(code[pc + 3]));

        switch (opcode) {
            1 => code[c] = code[a] + code[b],
            2 => code[c] = code[a] * code[b],
            else => break,
        }
    }
    return code[0];
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var codes: [200]i64 = undefined;
    var len: usize = 0;

    var num: i64 = 0;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            num = num * 10 + (c - '0');
        } else if (c == ',' or c == '\n') {
            if (num >= 0) {
                codes[len] = num;
                len += 1;
            }
            num = 0;
        }
    }
    if (num >= 0) {
        codes[len] = num;
        len += 1;
    }


    const code1 = try allocator.dupe(i64, codes[0..len]);
    defer allocator.free(code1);
    const code2 = try allocator.dupe(i64, codes[0..len]);
    defer allocator.free(code2);


    const c_coeff = execute(code1, 0, 0);
    const a_coeff = execute(code2, 1, 0) - c_coeff;


    const part1 = a_coeff * 12 + c_coeff + 2;


    const target: i64 = 19690720;


    const k = target - c_coeff;
    const noun = @divFloor(k, a_coeff);
    const verb = k - (noun * a_coeff);
    const part2 = 100 * noun + verb;

    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    const allocator = arena.allocator();

    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}

