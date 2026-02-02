const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

const MOD: u64 = 20201227;

fn modPow(base: u64, exp: u64) u64 {
    var result: u64 = 1;
    var b = base % MOD;
    var e = exp;
    while (e != 0) : (e >>= 1) {
        if ((e & 1) != 0) result = (result * b) % MOD;
        b = (b * b) % MOD;
    }
    return result;
}

fn discreteLog(public_key: u64) u64 {
    const m: u64 = 4495;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var map = std.AutoHashMap(u64, u64).init(allocator);
    map.ensureTotalCapacity(@intCast(m)) catch unreachable;

    var a: u64 = 1;
    var j: u64 = 0;
    while (j < m) : (j += 1) {
        map.putAssumeCapacity(a, j);
        a = (a * 7) % MOD;
    }

    var b = public_key;
    var i: u64 = 0;
    while (i < m) : (i += 1) {
        if (map.get(b)) |found| return i * m + found;
        b = (b * 680915) % MOD;
    }

    unreachable;
}

fn solve(input: []const u8) Result {
    var numbers: [2]u64 = undefined;
    var count: usize = 0;
    var idx: usize = 0;
    while (idx < input.len and count < 2) : (idx += 1) {
        if (input[idx] < '0' or input[idx] > '9') continue;
        var n: u64 = 0;
        while (idx < input.len and input[idx] >= '0' and input[idx] <= '9') : (idx += 1) {
            n = n * 10 + @as(u64, input[idx] - '0');
        }
        numbers[count] = n;
        count += 1;
    }

    const card_public = numbers[0];
    const door_public = numbers[1];
    const loop = discreteLog(card_public);
    const part1 = modPow(door_public, loop);

    return .{ .p1 = part1, .p2 = 0 };
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
