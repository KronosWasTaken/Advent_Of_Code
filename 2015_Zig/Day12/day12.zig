const std = @import("std");

const Result = struct {
    next: usize,
    ignore: bool,
    value: i32,
};

var p1_sum: i32 = 0;

fn parseNumber(input: []const u8, start: usize) Result {
    @setRuntimeSafety(false);
    const neg = input[start] == '-';
    var end = start + @as(usize, @intFromBool(neg));
    var acc: i32 = 0;
    while (input[end] >= '0' and input[end] <= '9') : (end += 1) {
        acc = acc * 10 + @as(i32, input[end] - '0');
    }
    const val = if (neg) -acc else acc;
    p1_sum += val;
    return .{ .next = end, .ignore = false, .value = val };
}

inline fn skipString(input: []const u8, start: usize) usize {
    @setRuntimeSafety(false);
    var end = start + 1;
    while (input[end] != '"') : (end += 1) {}
    return end + 1;
}

fn parseString(input: []const u8, start: usize) Result {
    @setRuntimeSafety(false);
    const s = start + 1;
    var end = s;
    while (input[end] != '"') : (end += 1) {}
    const is_red = (end - s == 3 and input[s] == 'r' and input[s + 1] == 'e' and input[s + 2] == 'd');
    return .{ .next = end + 1, .ignore = is_red, .value = 0 };
}

fn parseJson(input: []const u8, start: usize) Result {
    @setRuntimeSafety(false);
    return switch (input[start]) {
        '[' => parseArray(input, start),
        '{' => parseObject(input, start),
        '"' => parseString(input, start),
        else => parseNumber(input, start),
    };
}

fn parseArray(input: []const u8, start: usize) Result {
    @setRuntimeSafety(false);
    var index = start;
    var total: i32 = 0;
    while (input[index] != ']') {
        const res = parseJson(input, index + 1);
        index = res.next;
        total += res.value;
    }
    return .{ .next = index + 1, .ignore = false, .value = total };
}

fn parseObject(input: []const u8, start: usize) Result {
    @setRuntimeSafety(false);
    var index = start;
    var total: i32 = 0;
    var ignore = false;
    while (input[index] != '}') {
        const key_next = skipString(input, index + 1);
        const second = parseJson(input, key_next + 1);
        index = second.next;
        total += second.value;
        ignore = ignore or second.ignore;
    }
    return .{ .next = index + 1, .ignore = false, .value = if (ignore) 0 else total };
}

inline fn solve(input: []const u8) struct { p1: i32, p2: i32 } {
    @setRuntimeSafety(false);
    p1_sum = 0;
    const p2 = parseJson(input, 0).value;
    return .{ .p1 = p1_sum, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
