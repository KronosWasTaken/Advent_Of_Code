const std = @import("std");

const Result = struct {
    p1: u32,
    p2: []const u8,
};

fn solve(input: []const u8) !Result {
    const allocator = std.heap.page_allocator;
    var locks = std.ArrayListUnmanaged(u32){};
    defer locks.deinit(allocator);
    var keys = std.ArrayListUnmanaged(u32){};
    defer keys.deinit(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');
    var block: [7][]const u8 = undefined;
    var count: usize = 0;

    while (lines.next()) |raw| {
        var line = raw;
        if (line.len > 0 and line[line.len - 1] == '\r') line = line[0 .. line.len - 1];
        if (line.len == 0) {
            if (count > 0) {
                processBlock(block[0..count], &locks, &keys, allocator) catch |err| return err;
                count = 0;
            }
            continue;
        }
        if (count < block.len) {
            block[count] = line;
            count += 1;
        }
    }
    if (count > 0) {
        try processBlock(block[0..count], &locks, &keys, allocator);
    }

    var total: u32 = 0;
    for (locks.items) |lock| {
        for (keys.items) |key| {
            if ((lock & key) == 0) total += 1;
        }
    }

    return .{ .p1 = total, .p2 = "n/a" };
}

fn processBlock(block: [][]const u8, locks: *std.ArrayListUnmanaged(u32), keys: *std.ArrayListUnmanaged(u32), allocator: std.mem.Allocator) !void {
    if (block.len < 6) return;
    const is_lock = block[0][0] == '#';
    var bits: u32 = 0;
    var row: usize = 1;
    while (row < 6 and row < block.len) : (row += 1) {
        const line = block[row];
        var col: usize = 0;
        while (col < line.len and col < 5) : (col += 1) {
            bits = (bits << 1) | @as(u32, line[col] & 1);
        }
    }
    if (is_lock) {
        try locks.append(allocator, bits);
    } else {
        try keys.append(allocator, bits);
    }
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {s}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
