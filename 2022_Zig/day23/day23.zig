const std = @import("std");

const HEIGHT: usize = 210;

const Direction = enum { North, South, West, East };

const U256 = struct {
    left: u128,
    right: u128,

    fn zero() U256 {
        return .{ .left = 0, .right = 0 };
    }

    fn setBit(self: *U256, offset: usize) void {
        if (offset < 128) {
            self.left |= (@as(u128, 1) << @as(u7, @intCast(127 - offset)));
        } else {
            self.right |= (@as(u128, 1) << @as(u7, @intCast(255 - offset)));
        }
    }

    fn asArray(self: U256) [32]u8 {
        var out: [32]u8 = undefined;
        const left_bytes = std.mem.toBytes(@byteSwap(self.left));
        const right_bytes = std.mem.toBytes(@byteSwap(self.right));
        std.mem.copyForwards(u8, out[0..16], left_bytes[0..]);
        std.mem.copyForwards(u8, out[16..32], right_bytes[0..]);
        return out;
    }

    fn nonZero(self: U256) bool {
        return self.left != 0 or self.right != 0;
    }

    fn shl(self: U256) U256 {
        return .{ .left = (self.left << 1) | (self.right >> 127), .right = (self.right << 1) };
    }

    fn shr(self: U256) U256 {
        return .{ .left = (self.left >> 1), .right = (self.left << 127) | (self.right >> 1) };
    }

    fn bitAnd(self: U256, rhs: U256) U256 {
        return .{ .left = self.left & rhs.left, .right = self.right & rhs.right };
    }

    fn bitOr(self: U256, rhs: U256) U256 {
        return .{ .left = self.left | rhs.left, .right = self.right | rhs.right };
    }

    fn bitNot(self: U256) U256 {
        return .{ .left = ~self.left, .right = ~self.right };
    }
};

const Input = struct {
    grid: [HEIGHT]U256,
    north: [HEIGHT]U256,
    south: [HEIGHT]U256,
    west: [HEIGHT]U256,
    east: [HEIGHT]U256,
};

const Result = struct {
    p1: usize,
    p2: u32,
};

fn parse(input: []const u8) Input {
    const offset = 70;
    var grid: [HEIGHT]U256 = [_]U256{U256.zero()} ** HEIGHT;

    var y: usize = 0;
    var x: usize = 0;
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        const b = input[i];
        if (b == '\r') continue;
        if (b == '\n') {
            y += 1;
            x = 0;
            continue;
        }
        if (b == '#') {
            grid[offset + y].setBit(offset + x);
        }
        x += 1;
    }

    return .{ .grid = grid, .north = [_]U256{U256.zero()} ** HEIGHT, .south = [_]U256{U256.zero()} ** HEIGHT, .west = [_]U256{U256.zero()} ** HEIGHT, .east = [_]U256{U256.zero()} ** HEIGHT };
}

fn step(input: *Input, order: *[4]Direction) bool {
    var grid = &input.grid;
    var north = &input.north;
    var south = &input.south;
    var west = &input.west;
    var east = &input.east;

    var start_row: usize = 0;
    while (start_row < HEIGHT and !grid[start_row].nonZero()) : (start_row += 1) {}
    if (start_row == 0) {
        start_row = 1;
    } else {
        start_row -= 1;
    }
    var end_row: usize = HEIGHT - 1;
    while (end_row > 0 and !grid[end_row].nonZero()) : (end_row -= 1) {}
    end_row += 2;

    var moved = false;

    var prev: U256 = grid[0].shl().bitOr(grid[0]).bitOr(grid[0].shr()).bitNot();
    var cur: U256 = grid[1].shl().bitOr(grid[1]).bitOr(grid[1].shr()).bitNot();
    var next: U256 = grid[2].shl().bitOr(grid[2]).bitOr(grid[2].shr()).bitNot();

    var i: usize = start_row;
    while (i < end_row) : (i += 1) {
        prev = cur;
        cur = next;
        next = grid[i + 1].shl().bitOr(grid[i + 1]).bitOr(grid[i + 1].shr()).bitNot();

        var up = prev;
        var down = next;
        const vertical = grid[i - 1].bitOr(grid[i]).bitOr(grid[i + 1]).bitNot();
        var left = vertical.shr();
        var right = vertical.shl();
        var remaining = grid[i].bitAnd(up.bitAnd(down).bitAnd(left).bitAnd(right).bitNot());

        for (order) |direction| {
            switch (direction) {
                .North => {
                    up = up.bitAnd(remaining);
                    remaining = remaining.bitAnd(up.bitNot());
                },
                .South => {
                    down = down.bitAnd(remaining);
                    remaining = remaining.bitAnd(down.bitNot());
                },
                .West => {
                    left = left.bitAnd(remaining);
                    remaining = remaining.bitAnd(left.bitNot());
                },
                .East => {
                    right = right.bitAnd(remaining);
                    remaining = remaining.bitAnd(right.bitNot());
                },
            }
        }

        north[i - 1] = up;
        south[i + 1] = down;
        west[i] = left.shl();
        east[i] = right.shr();
    }

    i = start_row;
    while (i < end_row) : (i += 1) {
        const up = north[i];
        const down = south[i];
        const left = west[i];
        const right = east[i];
        north[i] = north[i].bitAnd(down.bitNot());
        south[i] = south[i].bitAnd(up.bitNot());
        west[i] = west[i].bitAnd(right.bitNot());
        east[i] = east[i].bitAnd(left.bitNot());
    }

    i = start_row;
    while (i < end_row) : (i += 1) {
        const same = grid[i].bitAnd(north[i - 1].bitOr(south[i + 1]).bitOr(west[i].shr()).bitOr(east[i].shl()).bitNot());
        const change = north[i].bitOr(south[i]).bitOr(west[i]).bitOr(east[i]);
        grid[i] = same.bitOr(change);
        if (change.nonZero()) moved = true;
    }

    const first = order[0];
    order[0] = order[1];
    order[1] = order[2];
    order[2] = order[3];
    order[3] = first;
    return moved;
}

fn solve(input: []const u8) Result {
    var parsed = parse(input);
    var order = [_]Direction{ .North, .South, .West, .East };

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        _ = step(&parsed, &order);
    }

    const grid = parsed.grid;
    var elves: usize = 0;
    for (grid) |row| {
        const array = row.asArray();
        for (array) |b| elves += @popCount(b);
    }

    var min_y: usize = 0;
    while (min_y < HEIGHT and !grid[min_y].nonZero()) : (min_y += 1) {}
    var max_y: usize = HEIGHT - 1;
    while (!grid[max_y].nonZero()) : (max_y -= 1) {}

    var combined = U256.zero();
    for (grid) |row| combined = combined.bitOr(row);
    const array = combined.asArray();
    var left: usize = 0;
    while (left < 32 and array[left] == 0) : (left += 1) {}
    var right: usize = 31;
    while (array[right] == 0) : (right -= 1) {}

    const min_x = 8 * left + @clz(array[left]);
    const max_x = 8 * right + (7 - @ctz(array[right]));

    const p1 = (max_x - min_x + 1) * (max_y - min_y + 1) - elves;

    parsed = parse(input);
    order = [_]Direction{ .North, .South, .West, .East };
    var moved = true;
    var count: u32 = 0;
    while (moved) {
        moved = step(&parsed, &order);
        count += 1;
    }

    return .{ .p1 = p1, .p2 = count };
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
