const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

const Seat = enum(u8) { floor = '.', empty = 'L', full = '#' };

const NeighborList = struct {
    counts: []u8,
    indices: []u32,
    bases: []u32,
};

fn parseGrid(allocator: std.mem.Allocator, input: []const u8) !struct { width: usize, height: usize, cells: []Seat } {
    var width: usize = 0;
    while (width < input.len and input[width] != '\n' and input[width] != '\r') : (width += 1) {}

    var cells = std.ArrayListUnmanaged(Seat){};
    errdefer cells.deinit(allocator);

    var i: usize = 0;
    var height: usize = 0;
    while (i < input.len) {
        if (input[i] == '\n' or input[i] == '\r') {
            i += 1;
            continue;
        }
        if (i + width > input.len) break;
        var j: usize = 0;
        while (j < width) : (j += 1) {
            const ch = input[i + j];
            const seat: Seat = switch (ch) {
                'L' => .empty,
                '#' => .full,
                else => .floor,
            };
            try cells.append(allocator, seat);
        }
        height += 1;
        i += width;
        if (i < input.len and input[i] == '\r') i += 1;
        if (i < input.len and input[i] == '\n') i += 1;
    }

    return .{ .width = width, .height = height, .cells = try cells.toOwnedSlice(allocator) };
}

fn buildSeatMap(allocator: std.mem.Allocator, cells: []const Seat, width: usize, height: usize) !struct { seat_indices: []i32, seat_positions: []u32 } {
    const total = width * height;
    var seat_indices = try allocator.alloc(i32, total);
    var positions = std.ArrayListUnmanaged(u32){};
    errdefer positions.deinit(allocator);

    var idx: usize = 0;
    while (idx < total) : (idx += 1) {
        if (cells[idx] == .floor) {
            seat_indices[idx] = -1;
        } else {
            seat_indices[idx] = @intCast(positions.items.len);
            try positions.append(allocator, @intCast(idx));
        }
    }

    return .{ .seat_indices = seat_indices, .seat_positions = try positions.toOwnedSlice(allocator) };
}

fn buildNeighbors(allocator: std.mem.Allocator, cells: []const Seat, width: usize, height: usize, seat_positions: []const u32, seat_indices: []const i32, visible: bool) !NeighborList {
    const seat_count = seat_positions.len;
    var counts = try allocator.alloc(u8, seat_count);
    var indices = try allocator.alloc(u32, seat_count * 8);
    var bases = try allocator.alloc(u32, seat_count);
    @memset(counts, 0);

    const dirs = [_]i32{ -1, 0, 1 };
    var seat_idx: usize = 0;
    while (seat_idx < seat_count) : (seat_idx += 1) {
        const pos = seat_positions[seat_idx];
        const x = @as(i32, @intCast(pos % width));
        const y = @as(i32, @intCast(pos / width));
        var count: u8 = 0;
        const base: u32 = @intCast(seat_idx * 8);
        bases[seat_idx] = base;

        for (dirs) |dx| {
            for (dirs) |dy| {
                if (dx == 0 and dy == 0) continue;
                var nx = x + dx;
                var ny = y + dy;
                while (nx >= 0 and ny >= 0 and nx < @as(i32, @intCast(width)) and ny < @as(i32, @intCast(height))) {
                    const idx = @as(usize, @intCast(ny)) * width + @as(usize, @intCast(nx));
                    if (cells[idx] != .floor) {
                        const target = seat_indices[idx];
                        if (target >= 0) {
                            indices[base + count] = @intCast(target);
                            count += 1;
                        }
                        break;
                    }
                    if (!visible) break;
                    nx += dx;
                    ny += dy;
                }
            }
        }

        counts[seat_idx] = count;
    }

    return .{ .counts = counts, .indices = indices, .bases = bases };
}

fn simulate(seat_states: []u8, neighbors: NeighborList, limit: u8) usize {
    const seat_count = neighbors.counts.len;
    const buffer = std.heap.page_allocator.alloc(u8, seat_count) catch unreachable;
    defer std.heap.page_allocator.free(buffer);

    var current = seat_states;
    var next = buffer;

    while (true) {
        var changed = false;
        var i: usize = 0;
        while (i < seat_count) : (i += 1) {
            const base = neighbors.bases[i];
            const count = neighbors.counts[i];
            var occ: u8 = 0;
            if (count > 0) occ += current[@as(usize, neighbors.indices[base])];
            if (count > 1) occ += current[@as(usize, neighbors.indices[base + 1])];
            if (count > 2) occ += current[@as(usize, neighbors.indices[base + 2])];
            if (count > 3) occ += current[@as(usize, neighbors.indices[base + 3])];
            if (count > 4) occ += current[@as(usize, neighbors.indices[base + 4])];
            if (count > 5) occ += current[@as(usize, neighbors.indices[base + 5])];
            if (count > 6) occ += current[@as(usize, neighbors.indices[base + 6])];
            if (count > 7) occ += current[@as(usize, neighbors.indices[base + 7])];

            const curr = current[i];
            const new_state: u8 = if (curr == 0 and occ == 0)
                1
            else if (curr == 1 and occ >= limit)
                0
            else
                curr;

            next[i] = new_state;
            if (new_state != curr) changed = true;
        }
        if (!changed) break;

        const tmp = current;
        current = next;
        next = tmp;
    }

    var total: usize = 0;
    for (current) |state| total += state;
    return total;
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const grid = parseGrid(arena.allocator(), input) catch unreachable;
    const map = buildSeatMap(arena.allocator(), grid.cells, grid.width, grid.height) catch unreachable;
    const adj = buildNeighbors(arena.allocator(), grid.cells, grid.width, grid.height, map.seat_positions, map.seat_indices, false) catch unreachable;
    const vis = buildNeighbors(arena.allocator(), grid.cells, grid.width, grid.height, map.seat_positions, map.seat_indices, true) catch unreachable;

    const seat_count = map.seat_positions.len;
    const states1 = arena.allocator().alloc(u8, seat_count) catch unreachable;
    const states2 = arena.allocator().alloc(u8, seat_count) catch unreachable;

    var i: usize = 0;
    while (i < seat_count) : (i += 1) {
        const pos = map.seat_positions[i];
        states1[i] = @intFromBool(grid.cells[pos] == .full);
        states2[i] = states1[i];
    }

    const p1 = simulate(states1, adj, 4);
    const p2 = simulate(states2, vis, 5);

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
