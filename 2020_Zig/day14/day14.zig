const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

const Mask = struct {
    blanks: u64,
    ones: u64,
    zeroes: u64,
};

fn parseMask(line: []const u8) Mask {
    var blanks: u64 = 0;
    var ones: u64 = 0;
    var zeroes: u64 = 0;
    for (line, 0..) |c, j| {
        const bit: u64 = @as(u64, 1) << @intCast(35 - j);
        switch (c) {
            'X' => blanks |= bit,
            '0' => zeroes |= bit,
            '1' => ones |= bit,
            else => {},
        }
    }
    return .{ .blanks = blanks, .ones = ones, .zeroes = zeroes };
}

fn applyFloating(mem: *std.AutoHashMap(u64, u64), addr: u64, value: u64, mask: u64, allocator: std.mem.Allocator) void {
    var stack = std.ArrayListUnmanaged(struct { addr: u64, mask: u64 }){};
    defer stack.deinit(allocator);
    stack.append(allocator, .{ .addr = addr, .mask = mask }) catch unreachable;

    while (stack.items.len > 0) {
        const item = stack.pop().?;
        if (item.mask == 0) {
            mem.put(item.addr, value) catch unreachable;
            continue;
        }
        const lsb: u64 = @as(u64, 1) << @as(u6, @intCast(@ctz(item.mask)));
        const new_mask = item.mask & ~lsb;
        stack.append(allocator, .{ .addr = item.addr, .mask = new_mask }) catch unreachable;
        stack.append(allocator, .{ .addr = item.addr | lsb, .mask = new_mask }) catch unreachable;
    }
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var mem1 = std.AutoHashMap(u64, u64).init(arena.allocator());
    var mem2 = std.AutoHashMap(u64, u64).init(arena.allocator());

    var mask = Mask{ .blanks = 0, .ones = 0, .zeroes = 0 };

    var start: usize = 0;
    while (start < input.len) {
        var end = start;
        while (end < input.len and input[end] != '\n') : (end += 1) {}
        var line = input[start..end];
        if (line.len > 0 and line[line.len - 1] == '\r') line = line[0 .. line.len - 1];
        if (line.len == 0) {
            start = end + 1;
            continue;
        }

        if (std.mem.eql(u8, line[0..4], "mask")) {
            mask = parseMask(line[7..]);
        } else {
            const without_prefix = line[4..];
            const sep = std.mem.indexOf(u8, without_prefix, "] = ") orelse unreachable;
            const register = std.fmt.parseInt(u64, without_prefix[0..sep], 10) catch unreachable;
            const value = std.fmt.parseInt(u64, without_prefix[sep + 4 ..], 10) catch unreachable;

            mem1.put(register, (value & mask.blanks) | mask.ones) catch unreachable;

            const addr = (register & mask.zeroes) | mask.ones;
            applyFloating(&mem2, addr, value, mask.blanks, arena.allocator());
        }

        start = end + 1;
    }

    var part1: u64 = 0;
    var it1 = mem1.valueIterator();
    while (it1.next()) |val| part1 += val.*;

    var part2: u64 = 0;
    var it2 = mem2.valueIterator();
    while (it2.next()) |val| part2 += val.*;

    return .{ .p1 = part1, .p2 = part2 };
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
