const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

const TileCoord = struct {
    q: i32,
    r: i32,
};

const ParseResult = struct {
    coords: []TileCoord,
    min_q: i32,
    max_q: i32,
    min_r: i32,
    max_r: i32,
};

fn parsePaths(input: []const u8, allocator: std.mem.Allocator) ParseResult {
    var i: usize = 0;
    var q: i32 = 0;
    var r: i32 = 0;

    var coords = std.ArrayListUnmanaged(TileCoord){};
    errdefer coords.deinit(allocator);
    var min_q: i32 = 0;
    var max_q: i32 = 0;
    var min_r: i32 = 0;
    var max_r: i32 = 0;
    var initialized = false;

    while (i < input.len) {
        q = 0;
        r = 0;
        while (i < input.len and input[i] != '\n') {
            const c = input[i];
            if (c == 'e') {
                q += 1;
                i += 1;
            } else if (c == 'w') {
                q -= 1;
                i += 1;
            } else if (c == 's') {
                const next = input[i + 1];
                if (next == 'e') {
                    r += 1;
                } else {
                    q -= 1;
                    r += 1;
                }
                i += 2;
            } else if (c == 'n') {
                const next = input[i + 1];
                if (next == 'e') {
                    q += 1;
                    r -= 1;
                } else {
                    r -= 1;
                }
                i += 2;
            } else {
                i += 1;
            }
        }
        if (i < input.len and input[i] == '\n') i += 1;

        coords.append(allocator, .{ .q = q, .r = r }) catch unreachable;
        if (!initialized) {
            min_q = q;
            max_q = q;
            min_r = r;
            max_r = r;
            initialized = true;
        } else {
            min_q = @min(min_q, q);
            max_q = @max(max_q, q);
            min_r = @min(min_r, r);
            max_r = @max(max_r, r);
        }
    }

    return .{
        .coords = coords.toOwnedSlice(allocator) catch unreachable,
        .min_q = min_q,
        .max_q = max_q,
        .min_r = min_r,
        .max_r = max_r,
    };
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const parsed = parsePaths(input, allocator);
    defer allocator.free(parsed.coords);

    const margin: i32 = 101;
    const width: usize = @intCast(parsed.max_q - parsed.min_q + 1 + 2 * margin);
    const height: usize = @intCast(parsed.max_r - parsed.min_r + 1 + 2 * margin);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var state = arena_alloc.alloc(u8, width * height) catch unreachable;
    var active = std.ArrayListUnmanaged(usize){};
    var counts = arena_alloc.alloc(u8, width * height) catch unreachable;
    var candidates = std.ArrayListUnmanaged(usize){};
    var next_active = std.ArrayListUnmanaged(usize){};

    @memset(state, 0);
    @memset(counts, 0);

    const q_offset: i32 = margin - parsed.min_q;
    const r_offset: i32 = margin - parsed.min_r;

    for (parsed.coords) |coord| {
        const col: usize = @intCast(coord.q + q_offset);
        const row: usize = @intCast(coord.r + r_offset);
        const index = row * width + col;
        if (state[index] == 1) {
            state[index] = 0;
        } else {
            state[index] = 1;
        }
    }

    for (state, 0..) |value, index| {
        if (value == 1) active.append(arena_alloc, index) catch unreachable;
    }

    const part1 = active.items.len;

    var day: usize = 0;
    while (day < 100) : (day += 1) {
        @memset(counts, 0);
        candidates.items.len = 0;
        next_active.items.len = 0;

        for (active.items) |tile| {
            const neighbors = [_]usize{
                tile + 1,
                tile - 1,
                tile + width,
                tile - width,
                tile + 1 - width,
                tile - 1 + width,
            };
            for (neighbors) |neighbor| {
                const updated = counts[neighbor] + 1;
                counts[neighbor] = updated;
                if (updated == 2) {
                    candidates.append(arena_alloc, neighbor) catch unreachable;
                }
            }
        }

        for (active.items) |tile| {
            const count = counts[tile];
            if (count == 1 or count == 2) {
                next_active.append(arena_alloc, tile) catch unreachable;
            }
        }

        for (candidates.items) |tile| {
            if (state[tile] == 0 and counts[tile] == 2) {
                next_active.append(arena_alloc, tile) catch unreachable;
            }
        }

        @memset(state, 0);
        for (next_active.items) |tile| {
            state[tile] = 1;
        }

        const temp = active;
        active = next_active;
        next_active = temp;
    }

    return .{ .p1 = part1, .p2 = active.items.len };
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
