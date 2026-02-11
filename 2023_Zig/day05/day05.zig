const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

const Stage = struct {
    ranges: []const [3]u64,
};

const Input = struct {
    seeds: []const u64,
    stages: []const Stage,
};

fn nextNumber(line: []const u8, idx: *usize) ?u64 {
    var i = idx.*;
    while (i < line.len and (line[i] < '0' or line[i] > '9')) : (i += 1) {}
    if (i >= line.len) {
        idx.* = i;
        return null;
    }
    var value: u64 = 0;
    while (i < line.len and line[i] >= '0' and line[i] <= '9') : (i += 1) {
        value = value * 10 + (line[i] - '0');
    }
    idx.* = i;
    return value;
}

fn parseInput(alloc: std.mem.Allocator, input: []const u8) !Input {
    var lines = std.mem.splitScalar(u8, input, '\n');
    const first_raw = lines.next() orelse return Input{ .seeds = &[_]u64{}, .stages = &[_]Stage{} };
    const first = std.mem.trimRight(u8, first_raw, "\r");
    var seeds_list: std.ArrayListUnmanaged(u64) = .{};
    var idx: usize = 0;
    while (nextNumber(first, &idx)) |value| {
        try seeds_list.append(alloc, value);
    }

    var stages_list: std.ArrayListUnmanaged(Stage) = .{};
    var current_ranges: std.ArrayListUnmanaged([3]u64) = .{};
    defer current_ranges.deinit(alloc);

    while (lines.next()) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");
        if (line.len == 0) {
            if (current_ranges.items.len > 0) {
                const owned = try alloc.dupe([3]u64, current_ranges.items);
                try stages_list.append(alloc, .{ .ranges = owned });
                current_ranges.clearRetainingCapacity();
            }
            continue;
        }
        if (std.mem.indexOfScalar(u8, line, ':') != null) continue;
        idx = 0;
        const dest = nextNumber(line, &idx) orelse continue;
        const start = nextNumber(line, &idx) orelse continue;
        const length = nextNumber(line, &idx) orelse continue;
        try current_ranges.append(alloc, .{ dest, start, start + length });
    }
    if (current_ranges.items.len > 0) {
        const owned = try alloc.dupe([3]u64, current_ranges.items);
        try stages_list.append(alloc, .{ .ranges = owned });
    }

    return .{ .seeds = seeds_list.items, .stages = stages_list.items };
}

fn part1(input: Input) u64 {
    const seeds = input.seeds;
    var tmp = std.ArrayListUnmanaged(u64){};
    defer tmp.deinit(std.heap.page_allocator);
    tmp.appendSlice(std.heap.page_allocator, seeds) catch return 0;

    for (input.stages) |stage| {
        for (tmp.items) |*seed| {
            for (stage.ranges) |range| {
                const dest = range[0];
                const start = range[1];
                const end = range[2];
                if (start <= seed.* and seed.* < end) {
                    seed.* = seed.* - start + dest;
                    break;
                }
            }
        }
    }

    var min_val = tmp.items[0];
    for (tmp.items[1..]) |v| {
        if (v < min_val) min_val = v;
    }
    return min_val;
}

fn part2(input: Input, alloc: std.mem.Allocator) u64 {
    var current: std.ArrayListUnmanaged([2]u64) = .{};
    var next: std.ArrayListUnmanaged([2]u64) = .{};
    var next_stage: std.ArrayListUnmanaged([2]u64) = .{};
    defer current.deinit(alloc);
    defer next.deinit(alloc);
    defer next_stage.deinit(alloc);

    var i: usize = 0;
    while (i + 1 < input.seeds.len) : (i += 2) {
        const start = input.seeds[i];
        const length = input.seeds[i + 1];
        current.append(alloc, .{ start, start + length }) catch return 0;
    }

    for (input.stages) |stage| {
        for (stage.ranges) |range| {
            const dest = range[0];
            const s2 = range[1];
            const e2 = range[2];
            var idx_cur: usize = 0;
            while (idx_cur < current.items.len) : (idx_cur += 1) {
                const s1 = current.items[idx_cur][0];
                const e1 = current.items[idx_cur][1];
                const x1 = if (s1 > s2) s1 else s2;
                const x2 = if (e1 < e2) e1 else e2;
                if (x1 >= x2) {
                    next.append(alloc, .{ s1, e1 }) catch return 0;
                } else {
                    next_stage.append(alloc, .{ x1 - s2 + dest, x2 - s2 + dest }) catch return 0;
                    if (s1 < x1) next.append(alloc, .{ s1, x1 }) catch return 0;
                    if (x2 < e1) next.append(alloc, .{ x2, e1 }) catch return 0;
                }
            }
            current.clearRetainingCapacity();
            const tmp = current;
            current = next;
            next = tmp;
            next.clearRetainingCapacity();
        }
        current.appendSlice(alloc, next_stage.items) catch return 0;
        next_stage.clearRetainingCapacity();
    }

    var min_val = current.items[0][0];
    for (current.items[1..]) |r| {
        if (r[0] < min_val) min_val = r[0];
    }
    return min_val;
}

pub fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const parsed = parseInput(alloc, input) catch return .{ .p1 = 0, .p2 = 0 };
    const p1 = part1(parsed);
    const p2 = part2(parsed, alloc);
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
