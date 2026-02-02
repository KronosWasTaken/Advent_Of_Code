const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

fn solve(input: []const u8) Result {
    var sum1: u64 = 0;
    var sum2: u64 = 0;
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line_raw| {
        if (line_raw.len == 0) continue;
        const line = if (line_raw[line_raw.len - 1] == '\r')
            line_raw[0 .. line_raw.len - 1]
        else
            line_raw;
        sum1 += eval1(line);
        sum2 += eval2(line);
    }
    return .{ .p1 = sum1, .p2 = sum2 };
}

fn eval1(line: []const u8) u64 {
    var idx: usize = 0;
    return parse1(line, &idx);
}

fn eval2(line: []const u8) u64 {
    var idx: usize = 0;
    return parse2(line, &idx);
}

fn skipSpaces(line: []const u8, idx: *usize) void {
    while (idx.* < line.len and line[idx.*] == ' ') idx.* += 1;
}

fn value1(line: []const u8, idx: *usize) u64 {
    skipSpaces(line, idx);
    const c = line[idx.*];
    if (c == '(') {
        idx.* += 1;
        return parse1(line, idx);
    }
    idx.* += 1;
    return @as(u64, c - '0');
}

fn value2(line: []const u8, idx: *usize) u64 {
    skipSpaces(line, idx);
    const c = line[idx.*];
    if (c == '(') {
        idx.* += 1;
        return parse2(line, idx);
    }
    idx.* += 1;
    return @as(u64, c - '0');
}

fn parse1(line: []const u8, idx: *usize) u64 {
    var total = value1(line, idx);
    while (true) {
        skipSpaces(line, idx);
        if (idx.* >= line.len or line[idx.*] == ')') {
            if (idx.* < line.len and line[idx.*] == ')') idx.* += 1;
            return total;
        }
        const op = line[idx.*];
        idx.* += 1;
        const v = value1(line, idx);
        if (op == '+') total += v else total *= v;
    }
}

fn parse2(line: []const u8, idx: *usize) u64 {
    var total = value2(line, idx);
    while (true) {
        skipSpaces(line, idx);
        if (idx.* >= line.len or line[idx.*] == ')') {
            if (idx.* < line.len and line[idx.*] == ')') idx.* += 1;
            return total;
        }
        const op = line[idx.*];
        idx.* += 1;
        if (op == '+') {
            total += value2(line, idx);
        } else {
            total *= parse2(line, idx);
            return total;
        }
    }
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
