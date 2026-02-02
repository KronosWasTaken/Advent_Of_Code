const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

fn parseNumbers(allocator: std.mem.Allocator, input: []const u8) ![]u64 {
    var list = std.ArrayListUnmanaged(u64){};
    errdefer list.deinit(allocator);
    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and (input[i] == '\n' or input[i] == '\r')) : (i += 1) {}
        if (i >= input.len) break;
        var value: u64 = 0;
        while (i < input.len and input[i] >= '0') : (i += 1) {
            value = value * 10 + (input[i] - '0');
        }
        try list.append(allocator, value);
    }
    return list.toOwnedSlice(allocator);
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const numbers = parseNumbers(arena.allocator(), input) catch unreachable;

    const preamble: usize = 25;
    var invalid: u64 = 0;

    var i: usize = preamble;
    while (i < numbers.len) : (i += 1) {
        var found = false;
        var j: usize = i - preamble;
        while (j + 1 < i) : (j += 1) {
            var k: usize = j + 1;
            while (k < i) : (k += 1) {
                if (numbers[j] + numbers[k] == numbers[i]) {
                    found = true;
                    break;
                }
            }
            if (found) break;
        }
        if (!found) {
            invalid = numbers[i];
            break;
        }
    }

    var start: usize = 0;
    var end: usize = 2;
    var sum: u64 = numbers[0] + numbers[1];
    while (sum != invalid) {
        if (sum < invalid) {
            sum += numbers[end];
            end += 1;
        } else {
            sum -= numbers[start];
            start += 1;
        }
    }

    const slice = numbers[start..end];
    const min = std.mem.min(u64, slice);
    const max = std.mem.max(u64, slice);

    return .{ .p1 = invalid, .p2 = min + max };
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
