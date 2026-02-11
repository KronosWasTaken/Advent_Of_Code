const std = @import("std");

const Result = struct {
    p1: i32,
    p2: i32,
};

const Input = struct {
    width: i16,
    height: i16,
    rounded: []i16,
    fixed_north: []i16,
    fixed_west: []i16,
    fixed_south: []i16,
    fixed_east: []i16,
    roll_north: []i16,
    roll_west: []i16,
    roll_south: []i16,
    roll_east: []i16,
};

fn parseInput(alloc: std.mem.Allocator, input: []const u8) !Input {
    var width: i16 = 0;
    var height: i16 = 0;
    var cur: i16 = 0;
    for (input) |b| {
        if (b == '\r') continue;
        if (b == '\n') {
            if (cur > 0) {
                if (width == 0) width = cur;
                height += 1;
                cur = 0;
            }
        } else {
            cur += 1;
        }
    }
    if (cur > 0) {
        if (width == 0) width = cur;
        height += 1;
    }

    const grid_w: i16 = width + 2;
    const grid_h: i16 = height + 2;
    const stride: i16 = grid_w;
    const total = @as(usize, @intCast(grid_w * grid_h));

    var grid = try alloc.alloc(u8, total);
    @memset(grid, '#');

    var rounded_list: std.ArrayListUnmanaged(i16) = .{};
    var y: i16 = 0;
    var x: i16 = 0;
    var idx: usize = @as(usize, @intCast(stride + 1));
    for (input) |b| {
        if (b == '\r') continue;
        if (b == '\n') {
            if (x > 0) {
                y += 1;
                x = 0;
                idx = @as(usize, @intCast((y + 1) * stride + 1));
            }
            continue;
        }
        grid[idx] = b;
        if (b == 'O') {
            rounded_list.append(alloc, @intCast(idx)) catch return error.OutOfMemory;
        }
        idx += 1;
        x += 1;
    }

    const size = total;
    var fixed_north = try alloc.alloc(i16, size);
    var fixed_west = try alloc.alloc(i16, size);
    var fixed_south = try alloc.alloc(i16, size);
    var fixed_east = try alloc.alloc(i16, size);

    var roll_north: std.ArrayListUnmanaged(i16) = .{};
    var roll_west: std.ArrayListUnmanaged(i16) = .{};
    var roll_south: std.ArrayListUnmanaged(i16) = .{};
    var roll_east: std.ArrayListUnmanaged(i16) = .{};

    var xi: i16 = 0;
    while (xi < grid_w) : (xi += 1) {
        var yi: i16 = 0;
        while (yi < grid_h) : (yi += 1) {
            const index = @as(usize, @intCast(yi * grid_w + xi));
            if (grid[index] == '#') roll_north.append(alloc, @intCast(index)) catch return error.OutOfMemory;
            fixed_north[index] = @intCast(roll_north.items.len - 1);
        }
    }

    var yi: i16 = 0;
    while (yi < grid_h) : (yi += 1) {
        xi = 0;
        while (xi < grid_w) : (xi += 1) {
            const index = @as(usize, @intCast(yi * grid_w + xi));
            if (grid[index] == '#') roll_west.append(alloc, @intCast(index)) catch return error.OutOfMemory;
            fixed_west[index] = @intCast(roll_west.items.len - 1);
        }
    }

    xi = 0;
    while (xi < grid_w) : (xi += 1) {
        yi = grid_h - 1;
        while (true) {
            const index = @as(usize, @intCast(yi * grid_w + xi));
            if (grid[index] == '#') roll_south.append(alloc, @intCast(index)) catch return error.OutOfMemory;
            fixed_south[index] = @intCast(roll_south.items.len - 1);
            if (yi == 0) break;
            yi -= 1;
        }
    }

    yi = 0;
    while (yi < grid_h) : (yi += 1) {
        xi = grid_w - 1;
        while (true) {
            const index = @as(usize, @intCast(yi * grid_w + xi));
            if (grid[index] == '#') roll_east.append(alloc, @intCast(index)) catch return error.OutOfMemory;
            fixed_east[index] = @intCast(roll_east.items.len - 1);
            if (xi == 0) break;
            xi -= 1;
        }
    }

    return .{
        .width = grid_w,
        .height = grid_h,
        .rounded = try rounded_list.toOwnedSlice(alloc),
        .fixed_north = fixed_north,
        .fixed_west = fixed_west,
        .fixed_south = fixed_south,
        .fixed_east = fixed_east,
        .roll_north = try roll_north.toOwnedSlice(alloc),
        .roll_west = try roll_west.toOwnedSlice(alloc),
        .roll_south = try roll_south.toOwnedSlice(alloc),
        .roll_east = try roll_east.toOwnedSlice(alloc),
    };
}

fn tilt(rounded: []i16, fixed: []const i16, roll: []const i16, direction: i16, scratch: []i16) []const i16 {
    @memcpy(scratch, roll);
    for (rounded) |*rock| {
        const index = @as(usize, @intCast(fixed[@intCast(rock.*)]));
        scratch[index] += direction;
        rock.* = scratch[index];
    }
    return scratch;
}

pub fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const parsed = parseInput(alloc, input) catch return .{ .p1 = 0, .p2 = 0 };

    const rounded1 = alloc.dupe(i16, parsed.rounded) catch return .{ .p1 = 0, .p2 = 0 };
    const scratch = alloc.alloc(i16, parsed.roll_north.len) catch return .{ .p1 = 0, .p2 = 0 };
    const state1 = tilt(rounded1, parsed.fixed_north, parsed.roll_north, @intCast(parsed.width), scratch);
    var p1: i32 = 0;
    for (parsed.roll_north, state1) |a, b| {
        var idx = a;
        while (idx < b) : (idx += parsed.width) {
            const y = @divTrunc(idx, parsed.width);
            p1 += parsed.height - 2 - y;
        }
    }

    const rounded2 = alloc.dupe(i16, parsed.rounded) catch return .{ .p1 = p1, .p2 = 0 };
    const SliceCtx = struct {
        pub fn hash(_: @This(), key: []i16) u64 {
            return std.hash.Wyhash.hash(0, std.mem.sliceAsBytes(key));
        }
        pub fn eql(_: @This(), a: []i16, b: []i16) bool {
            return std.mem.eql(i16, a, b);
        }
    };
    var seen = std.HashMap([]i16, usize, SliceCtx, std.hash_map.default_max_load_percentage).init(alloc);
    defer seen.deinit();

    var states = std.ArrayListUnmanaged([]i16){};
    defer states.deinit(alloc);

    var start: usize = 0;
    var end: usize = 0;
    while (true) {
        _ = tilt(rounded2, parsed.fixed_north, parsed.roll_north, @intCast(parsed.width), scratch);
        _ = tilt(rounded2, parsed.fixed_west, parsed.roll_west, 1, scratch);
        _ = tilt(rounded2, parsed.fixed_south, parsed.roll_south, -@as(i16, @intCast(parsed.width)), scratch);
        const state = tilt(rounded2, parsed.fixed_east, parsed.roll_east, -1, scratch);

        const owned = alloc.alloc(i16, state.len) catch return .{ .p1 = p1, .p2 = 0 };
        @memcpy(owned, state);
        if (seen.get(owned)) |prev| {
            start = prev;
            end = states.items.len;
            break;
        }
        seen.put(owned, states.items.len) catch return .{ .p1 = p1, .p2 = 0 };
        states.append(alloc, owned) catch return .{ .p1 = p1, .p2 = 0 };
    }

    const offset = 1_000_000_000 - 1 - start;
    const cycle_len = end - start;
    const target = start + (offset % cycle_len);
    const state = states.items[target];

    var p2: i32 = 0;
    for (parsed.roll_east, state) |a, b| {
        const n = a - b;
        const y = @divTrunc(a, parsed.width);
        p2 += n * (parsed.height - 1 - y);
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
