const std = @import("std");

const Result = struct { p1: usize, p2: []const u8 };

const U256 = struct {
    left: u128 = 0,
    right: u128 = 0,

    fn bitSet(self: *U256, offset: usize) void {
        if (offset < 128) {
            self.right |= @as(u128, 1) << @as(u7, @intCast(offset));
        } else {
            self.left |= @as(u128, 1) << @as(u7, @intCast(offset - 128));
        }
    }

    fn nonZero(self: U256) bool {
        return self.left != 0 or self.right != 0;
    }

    fn leftRoll(self: U256, width: usize) U256 {
        if (width <= 128) {
            const mask = ~(@as(u128, 1) << @as(u7, @intCast(width)));
            const right = ((self.right << 1) & mask) | (self.right >> @as(u7, @intCast(width - 1)));
            return .{ .left = self.left, .right = right };
        }
        const mask = ~(@as(u128, 1) << @as(u7, @intCast(width - 128)));
        const left = ((self.left << 1) & mask) | (self.right >> 127);
        const right = (self.right << 1) | (self.left >> @as(u7, @intCast(width - 129)));
        return .{ .left = left, .right = right };
    }

    fn rightRoll(self: U256, width: usize) U256 {
        if (width <= 128) {
            const right = (self.right >> 1) | ((self.right & 1) << @as(u7, @intCast(width - 1)));
            return .{ .left = self.left, .right = right };
        }
        const left = (self.left >> 1) | ((self.right & 1) << @as(u7, @intCast(width - 129)));
        const right = (self.right >> 1) | ((self.left & 1) << 127);
        return .{ .left = left, .right = right };
    }

    fn bitAnd(self: U256, other: U256) U256 {
        return .{ .left = self.left & other.left, .right = self.right & other.right };
    }

    fn bitOr(self: U256, other: U256) U256 {
        return .{ .left = self.left | other.left, .right = self.right | other.right };
    }

    fn bitNot(self: U256) U256 {
        return .{ .left = ~self.left, .right = ~self.right };
    }
};

const State = struct {
    width: usize,
    height: usize,
    across: []U256,
    down: []U256,
};

fn parse(input: []const u8, allocator: std.mem.Allocator) State {
    var lines = std.ArrayListUnmanaged([]const u8){};
    defer lines.deinit(allocator);

    var it = std.mem.splitScalar(u8, input, '\n');
    while (it.next()) |raw| {
        const line = std.mem.trimRight(u8, raw, "\r");
        if (line.len > 0) lines.append(allocator, line) catch unreachable;
    }

    const width = lines.items[0].len;
    const height = lines.items.len;
    const across = allocator.alloc(U256, height) catch unreachable;
    const down = allocator.alloc(U256, height) catch unreachable;

    var i: usize = 0;
    while (i < height) : (i += 1) {
        across[i] = .{};
        down[i] = .{};
        for (lines.items[i], 0..) |c, offset| {
            switch (c) {
                '>' => across[i].bitSet(offset),
                'v' => down[i].bitSet(offset),
                else => {},
            }
        }
    }

    return .{ .width = width, .height = height, .across = across, .down = down };
}

fn part1(input: State) usize {
    var across = input.across;
    var down = input.down;
    const width = input.width;
    const height = input.height;

    var changed = true;
    var count: usize = 0;

    while (changed) {
        changed = false;
        count += 1;

        var i: usize = 0;
        while (i < height) : (i += 1) {
            const candidates = across[i].leftRoll(width);
            const moved = candidates.bitAnd(across[i].bitOr(down[i]).bitNot());
            if (moved.nonZero()) changed = true;
            const stay = across[i].bitAnd(moved.rightRoll(width).bitNot());
            across[i] = moved.bitOr(stay);
        }

        const last_mask = across[0].bitOr(down[0]);
        var moved = down[height - 1].bitAnd(last_mask.bitNot());

        i = 0;
        while (i < height - 1) : (i += 1) {
            if (moved.nonZero()) changed = true;
            const mask = across[i + 1].bitOr(down[i + 1]);
            const stay = down[i].bitAnd(mask);
            const next_moved = down[i].bitAnd(mask.bitNot());
            down[i] = moved.bitOr(stay);
            moved = next_moved;
        }

        if (moved.nonZero()) changed = true;
        const stay_last = down[height - 1].bitAnd(last_mask);
        down[height - 1] = moved.bitOr(stay_last);
    }

    return count;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const state = parse(input, allocator);
    defer allocator.free(state.across);
    defer allocator.free(state.down);

    const p1 = part1(state);
    return .{ .p1 = p1, .p2 = "n/a" };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {s}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
