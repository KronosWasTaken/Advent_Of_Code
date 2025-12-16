const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const cwd = std.fs.cwd();
    const file_content = try cwd.readFileAlloc(allocator, "input.txt", 1024 * 1024);
    defer allocator.free(file_content);
    var timer = try std.time.Timer.start();
    const result = try solve(allocator, file_content);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn solve(allocator: std.mem.Allocator, input: []const u8) !Result {

    var ranges = try std.ArrayList([2]u32).initCapacity(allocator, 1000);
    defer ranges.deinit(allocator);
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0) continue;
        var it = std.mem.tokenizeScalar(u8, trimmed, '-');
        const start_str = it.next() orelse continue;
        const end_str = it.next() orelse continue;
        const start = try std.fmt.parseInt(u32, start_str, 10);
        const end = try std.fmt.parseInt(u32, end_str, 10);
        try ranges.append(allocator, [2]u32{ start, end });
    }

    const sort_fn = struct {
        fn lessThan(_: void, a: [2]u32, b: [2]u32) bool {
            return a[0] < b[0];
        }
    };
    std.mem.sort([2]u32, ranges.items, {}, sort_fn.lessThan);

    var index: u32 = 0;
    var p1: u32 = 0;
    var p2: u32 = 0;
    for (ranges.items) |range| {
        const start = range[0];
        const end = range[1];
        if (index < start) {
            if (p1 == 0) p1 = index;
            p2 += start - index;
        }

        index = @max(index, end +% 1);
        if (index == 0) break;
    }
    return .{ .p1 = p1, .p2 = p2 };
}
fn solve_old(allocator: std.mem.Allocator, input: []const u8) !Result {
    var ranges = std.ArrayListUnmanaged([2]u32){};
    defer ranges.deinit(allocator);
    var i: usize = 0;
    while (i < input.len) {

        while (i < input.len and (input[i] < '0' or input[i] > '9')) : (i += 1) {}
        if (i >= input.len) break;
        var start: u32 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            start = start * 10 + (input[i] - '0');
        }
        while (i < input.len and (input[i] < '0' or input[i] > '9')) : (i += 1) {}
        var end: u32 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            end = end * 10 + (input[i] - '0');
        }
        try ranges.append(allocator, .{ start, end });
    }

    std.mem.sort([2]u32, ranges.items, {}, lessThan);
    var p1: u32 = 0;
    var p2: u64 = 0;
    var current: u64 = 0;
    var found_p1 = false;
    const MAX_IP: u64 = 4294967295;
    for (ranges.items) |range| {
        if (current < range[0]) {

            if (!found_p1) {
                p1 = @intCast(current);
                found_p1 = true;
            }
            p2 += range[0] - current;
        }
        current = @max(current, @as(u64, range[1]) + 1);
    }

    if (current <= MAX_IP) {
        if (!found_p1) {
            p1 = @intCast(current);
        }
        p2 += (MAX_IP - current + 1);
    }
    return .{ .p1 = p1, .p2 = @intCast(p2) };
}
fn lessThan(_: void, a: [2]u32, b: [2]u32) bool {
    return a[0] < b[0];
}
