const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

const Stone = struct {
    first: usize,
    second: usize,
};

fn pow10(exp: u32) u64 {
    var result: u64 = 1;
    var i: u32 = 0;
    while (i < exp) : (i += 1) result *= 10;
    return result;
}

fn digitsCount(value: u64) u32 {
    var n = value;
    var digits: u32 = 0;
    while (n > 0) : (n /= 10) digits += 1;
    return if (digits == 0) 1 else digits;
}

fn indexOf(map: *std.AutoHashMap(u64, usize), todo: *std.ArrayListUnmanaged(u64), allocator: std.mem.Allocator, number: u64) !usize {
    if (map.get(number)) |idx| return idx;
    const idx = map.count();
    try map.put(number, idx);
    try todo.append(allocator, number);
    return idx;
}

fn count(input: []const u64, blinks: usize, allocator: std.mem.Allocator) !u64 {
    var stones: std.ArrayListUnmanaged(Stone) = .{};
    defer stones.deinit(allocator);
    var indices = std.AutoHashMap(u64, usize).init(allocator);
    defer indices.deinit();
    var todo: std.ArrayListUnmanaged(u64) = .{};
    defer todo.deinit(allocator);
    var numbers: std.ArrayListUnmanaged(u64) = .{};
    defer numbers.deinit(allocator);
    var current: std.ArrayListUnmanaged(u64) = .{};
    defer current.deinit(allocator);

    for (input) |number| {
        if (indices.get(number)) |idx| {
            current.items[idx] += 1;
        } else {
            const idx = indices.count();
            try indices.put(number, idx);
            try todo.append(allocator, number);
            try current.append(allocator, 1);
        }
    }

    var blink: usize = 0;
    while (blink < blinks) : (blink += 1) {
        std.mem.swap(std.ArrayListUnmanaged(u64), &numbers, &todo);
        for (numbers.items) |number| {
            const pair = if (number == 0) blk: {
                const first = try indexOf(&indices, &todo, allocator, 1);
                break :blk Stone{ .first = first, .second = std.math.maxInt(usize) };
            } else blk: {
                const digits = digitsCount(number);
                if (digits % 2 == 0) {
                    const power = pow10(digits / 2);
                    const first = try indexOf(&indices, &todo, allocator, number / power);
                    const second = try indexOf(&indices, &todo, allocator, number % power);
                    break :blk Stone{ .first = first, .second = second };
                }
                const first = try indexOf(&indices, &todo, allocator, number * 2024);
                break :blk Stone{ .first = first, .second = std.math.maxInt(usize) };
            };
            try stones.append(allocator, pair);
        }
        numbers.clearRetainingCapacity();

        var next: std.ArrayListUnmanaged(u64) = .{};
        const size = indices.count();
        try next.ensureTotalCapacity(allocator, size);
        next.items.len = size;
        @memset(next.items, 0);

        for (stones.items, 0..) |stone, i| {
            const amount = current.items[i];
            if (amount == 0) continue;
            next.items[stone.first] += amount;
            if (stone.second != std.math.maxInt(usize)) {
                next.items[stone.second] += amount;
            }
        }

        current.deinit(allocator);
        current = next;
    }

    var total: u64 = 0;
    for (current.items) |amount| total += amount;
    return total;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var numbers: std.ArrayListUnmanaged(u64) = .{};
    defer numbers.deinit(allocator);
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        if (input[i] < '0' or input[i] > '9') continue;
        var value: u64 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            value = value * 10 + @as(u64, input[i] - '0');
        }
        try numbers.append(allocator, value);
        if (i == 0) break;
        i -= 1;
    }

    const p1 = try count(numbers.items, 25, allocator);
    const p2 = try count(numbers.items, 75, allocator);
    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, std.heap.page_allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
