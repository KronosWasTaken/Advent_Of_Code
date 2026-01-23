const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

fn str2id(s: [3]u8) u16 {
    var id: u16 = 0;
    for (s) |c| {
        if (c >= 'A' and c <= 'Z') {
            id = id * 36 + (c - 'A');
        } else if (c >= '0' and c <= '9') {
            id = id * 36 + (c - '0' + 26);
        }
    }
    return id;
}

const Orbit = struct {
    parent: i16 = -1,
    depth: i16 = -1,
};

fn getDepth(orbits: []Orbit, idx: i32) i32 {
    if (idx == -1) return -1;
    if (orbits[@intCast(idx)].depth != -1) return orbits[@intCast(idx)].depth;
    const d = 1 + getDepth(orbits, orbits[@intCast(idx)].parent);
    orbits[@intCast(idx)].depth = @intCast(d);
    return d;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var idx_map = try allocator.alloc(i16, 65536);
    defer allocator.free(idx_map);
    @memset(idx_map, 0);

    var orbits = try std.ArrayList(Orbit).initCapacity(allocator, 5000);
    defer orbits.deinit(allocator);

    try orbits.append(allocator, Orbit{});

    var x: u16 = 0;
    var y: u16 = 0;
    var orbit_count: usize = 0;

    for (input) |c| {
        if ((c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9')) {
            orbit_count += 1;
            if (c >= 'A' and c <= 'Z') {
                x = x * 36 + (c - 'A');
            } else {
                x = x * 36 + (c - '0' + 26);
            }
        } else if (c == ')') {
            y = x;
            x = 0;
            orbit_count = 0;
        } else if (c == '\n' or c == 0) {
            if (x != 0 or y != 0) {

                for ([_]u16{ x, y }) |id| {
                    if (idx_map[id] != 0) continue;
                    idx_map[id] = @intCast(orbits.items.len);
                    try orbits.append(allocator, Orbit{});
                }
                orbits.items[@intCast(idx_map[x])].parent = idx_map[y];
                x = 0;
                y = 0;
            }
            orbit_count = 0;
        }
    }


    var part1: u32 = 0;
    for (0..orbits.items.len) |i| {
        const d = getDepth(orbits.items, @intCast(i));
        part1 += @intCast(@max(0, d));
    }


    const you_id = str2id("YOU"[0..3].*);
    const san_id = str2id("SAN"[0..3].*);
    const you_idx = idx_map[you_id];
    const san_idx = idx_map[san_id];

    var you = you_idx;
    var san = san_idx;

    var marked = try allocator.alloc(bool, orbits.items.len);
    defer allocator.free(marked);
    @memset(marked, false);

    var part2: u32 = @intCast(@max(0, orbits.items[@intCast(you)].depth + orbits.items[@intCast(san)].depth - 2));

    while (you >= 0) {
        marked[@intCast(you)] = true;
        you = orbits.items[@intCast(you)].parent;
    }

    while (!marked[@intCast(san)]) {
        san = orbits.items[@intCast(san)].parent;
    }

    part2 -= @intCast(@max(0, orbits.items[@intCast(san)].depth * 2));

    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    const allocator = arena.allocator();

    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}

