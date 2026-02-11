const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

fn reflectAxis(axis: []const u32, target: u32) ?usize {
    const size = axis.len;
    var i: usize = 1;
    while (i < size) : (i += 1) {
        const limit = if (i < size - i) i else size - i;
        var smudges: u32 = 0;
        var j: usize = 0;
        while (j < limit) : (j += 1) {
            smudges += @popCount(axis[i - j - 1] ^ axis[i + j]);
        }
        if (smudges == target) return i;
    }
    return null;
}

fn reflect(rows: []const u32, cols: []const u32, target: u32) u64 {
    if (reflectAxis(cols, target)) |x| return @as(u64, x);
    if (reflectAxis(rows, target)) |y| return @as(u64, 100 * y);
    return 0;
}

pub fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var clean = std.ArrayListUnmanaged(u8){};
    defer clean.deinit(alloc);
    clean.ensureTotalCapacity(alloc, input.len) catch return .{ .p1 = 0, .p2 = 0 };
    for (input) |b| if (b != '\r') clean.appendAssumeCapacity(b);

    var p1: u64 = 0;
    var p2: u64 = 0;

    var blocks = std.mem.splitSequence(u8, clean.items, "\n\n");
    while (blocks.next()) |block| {
        if (block.len == 0) continue;
        var lines = std.mem.splitScalar(u8, block, '\n');
        var rows = std.ArrayListUnmanaged(u32){};
        defer rows.deinit(alloc);
        var cols = std.ArrayListUnmanaged(u32){};
        defer cols.deinit(alloc);
        var width: usize = 0;

        while (lines.next()) |raw_line| {
            const line = std.mem.trimRight(u8, raw_line, "\r");
            if (line.len == 0) continue;
            if (width == 0) {
                width = line.len;
                cols.resize(alloc, width) catch return .{ .p1 = 0, .p2 = 0 };
                @memset(cols.items, 0);
            }
            var value: u32 = 0;
            var x: usize = 0;
            while (x < width) : (x += 1) {
                const bit: u32 = if (line[x] == '#') 1 else 0;
                value = (value << 1) | bit;
                cols.items[x] = (cols.items[x] << 1) | bit;
            }
            rows.append(alloc, value) catch return .{ .p1 = 0, .p2 = 0 };
        }

        if (rows.items.len > 0) {
            p1 += reflect(rows.items, cols.items, 0);
            p2 += reflect(rows.items, cols.items, 1);
        }
    }

    return .{ .p1 = p1, .p2 = p2 };
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
