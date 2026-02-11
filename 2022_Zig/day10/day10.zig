const std = @import("std");

const Result = struct {
    p1: i32,
    p2: []const u8,
};

fn isWhitespace(b: u8) bool {
    return b == ' ' or b == '\n' or b == '\r' or b == '\t';
}

fn solve(input: []const u8) Result {
    var xs = std.ArrayListUnmanaged(i32){};
    defer xs.deinit(std.heap.page_allocator);
    xs.append(std.heap.page_allocator, 1) catch unreachable;

    var x: i32 = 1;
    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and isWhitespace(input[i])) : (i += 1) {}
        if (i >= input.len) break;
        const start = i;
        while (i < input.len and !isWhitespace(input[i])) : (i += 1) {}
        const token = input[start..i];
        if (std.mem.eql(u8, token, "noop") or std.mem.eql(u8, token, "addx")) {
            xs.append(std.heap.page_allocator, x) catch unreachable;
            continue;
        }
        x += std.fmt.parseInt(i32, token, 10) catch 0;
        xs.append(std.heap.page_allocator, x) catch unreachable;
    }

    var p1: i32 = 0;
    var idx: usize = 19;
    while (idx < xs.items.len) : (idx += 40) {
        p1 += @as(i32, @intCast(idx + 1)) * xs.items[idx];
    }

    var output = std.ArrayListUnmanaged(u8){};
    defer output.deinit(std.heap.page_allocator);
    output.ensureTotalCapacity(std.heap.page_allocator, 6 * 41) catch unreachable;

    var row_start: usize = 0;
    while (row_start + 40 <= xs.items.len) : (row_start += 40) {
        output.append(std.heap.page_allocator, '\n') catch unreachable;
        var col: usize = 0;
        while (col < 40) : (col += 1) {
            const sprite = xs.items[row_start + col];
            const lit = @abs(@as(i32, @intCast(col)) - sprite) <= 1;
            output.append(std.heap.page_allocator, if (lit) '#' else '.') catch unreachable;
        }
    }

    return .{ .p1 = p1, .p2 = output.toOwnedSlice(std.heap.page_allocator) catch unreachable };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {s}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
