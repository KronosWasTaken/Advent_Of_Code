const std = @import("std");

const Result = struct { p1: u64, p2: u64 };

const Range = struct { digits: u32, size: u32 };
const Pair = struct { from: u64, to: u64 };

const FIRST = [_]Range{ .{ .digits = 2, .size = 1 }, .{ .digits = 4, .size = 2 }, .{ .digits = 6, .size = 3 }, .{ .digits = 8, .size = 4 }, .{ .digits = 10, .size = 5 } };
const SECOND = [_]Range{ .{ .digits = 3, .size = 1 }, .{ .digits = 5, .size = 1 }, .{ .digits = 6, .size = 2 }, .{ .digits = 7, .size = 1 }, .{ .digits = 9, .size = 3 }, .{ .digits = 10, .size = 2 } };
const THIRD = [_]Range{ .{ .digits = 6, .size = 1 }, .{ .digits = 10, .size = 1 } };

pub fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    var pairs = std.ArrayListUnmanaged(Pair){};
    defer pairs.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and input[i] < '0') : (i += 1) {}
        if (i >= input.len) break;
        var first: u64 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            first = first * 10 + @as(u64, input[i] - '0');
        }
        while (i < input.len and input[i] < '0') : (i += 1) {}
        var second: u64 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            second = second * 10 + @as(u64, input[i] - '0');
        }
        pairs.append(allocator, .{ .from = first, .to = second }) catch unreachable;
    }

    const p1 = sum(&FIRST, pairs.items);
    const p2 = p1 + sum(&SECOND, pairs.items) - sum(&THIRD, pairs.items);
    return .{ .p1 = p1, .p2 = p2 };
}

fn pow10(exp: u32) u64 {
    var result: u64 = 1;
    var i: u32 = 0;
    while (i < exp) : (i += 1) result *= 10;
    return result;
}

fn sum(ranges: []const Range, pairs: []const Pair) u64 {
    var result: u64 = 0;
    for (ranges) |range| {
        const digits_power = pow10(range.digits);
        const size_power = pow10(range.size);
        const step = (digits_power - 1) / (size_power - 1);
        const start = step * (size_power / 10);
        const end = step * (size_power - 1);

        for (pairs) |pair| {
            var lower = nextMultipleOf(pair.from, step);
            if (lower < start) lower = start;
            const upper = if (pair.to < end) pair.to else end;
            if (lower <= upper) {
                const n = (upper - lower) / step;
                const triangular = n * (n + 1) / 2;
                result += lower * (n + 1) + step * triangular;
            }
        }
    }
    return result;
}

fn nextMultipleOf(value: u64, step: u64) u64 {
    const rem = value % step;
    return if (rem == 0) value else value + (step - rem);
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
