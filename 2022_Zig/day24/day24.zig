const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

const Input = struct {
    lenx: usize,
    leny: usize,
    blizzards: [4][]u64,
};

fn parse(input: []const u8, allocator: std.mem.Allocator) !Input {
    var lines = std.ArrayListUnmanaged([]const u8){};
    defer lines.deinit(allocator);

    var start: usize = 0;
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        if (input[i] == '\n') {
            const slice = std.mem.trimRight(u8, input[start..i], "\r");
            if (slice.len > 0) lines.append(allocator, slice) catch unreachable;
            start = i + 1;
        }
    }
    if (start < input.len) {
        const slice = std.mem.trimRight(u8, input[start..], "\r");
        if (slice.len > 0) lines.append(allocator, slice) catch unreachable;
    }

    const lenx = lines.items[0].len - 2;
    const leny = lines.items.len - 2;
    if (leny >= 64) return error.InvalidInput;

    var blizzards: [4][]u64 = .{
        try allocator.alloc(u64, lenx),
        try allocator.alloc(u64, lenx),
        try allocator.alloc(u64, lenx),
        try allocator.alloc(u64, lenx),
    };
    for (blizzards) |col| @memset(col, (@as(u64, 1) << @as(u6, @intCast(leny))) - 1);

    var y: usize = 0;
    while (y < leny) : (y += 1) {
        const line = lines.items[y + 1];
        var x: usize = 0;
        while (x < lenx) : (x += 1) {
            const c = line[x + 1];
            switch (c) {
                '^' => blizzards[0][x] &= ~(@as(u64, 1) << @as(u6, @intCast(y))),
                'v' => blizzards[1][x] &= ~(@as(u64, 1) << @as(u6, @intCast(y))),
                '>' => blizzards[2][x] &= ~(@as(u64, 1) << @as(u6, @intCast(y))),
                '<' => blizzards[3][x] &= ~(@as(u64, 1) << @as(u6, @intCast(y))),
                else => {},
            }
        }
    }

    return .{ .lenx = lenx, .leny = leny, .blizzards = blizzards };
}

fn solveInner(lenx: usize, leny: usize, blizzards_in: [4][]u64, max_iter: usize) usize {
    var blizzards = blizzards_in;
    var reachable = std.heap.page_allocator.alloc(u64, lenx) catch unreachable;
    defer std.heap.page_allocator.free(reachable);
    @memset(reachable, 0);

    const mask_inside: u64 = (@as(u64, 1) << @as(u6, @intCast(leny))) - 1;
    const mask_last: u64 = @as(u64, 1) << @as(u6, @intCast(leny - 1));

    var steps: usize = 0;
    var iter: usize = 0;

    while (true) {
        const shift_up = struct {
            fn call(m: u64, h: usize) u64 {
                return (m >> 1) | ((m & 1) << @as(u6, @intCast(h - 1)));
            }
        };
        const shift_down = struct {
            fn call(m: u64, h: usize, last_mask: u64) u64 {
                return (m << 1) | ((m & last_mask) >> @as(u6, @intCast(h - 1)));
            }
        };

        var x: usize = 0;
        while (x < lenx) : (x += 1) {
            blizzards[0][x] = shift_up.call(blizzards[0][x], leny);
            blizzards[1][x] = shift_down.call(blizzards[1][x], leny, mask_last);
        }
        const last_col = blizzards[2][blizzards[2].len - 1];
        var idx: usize = blizzards[2].len - 1;
        while (idx > 0) : (idx -= 1) blizzards[2][idx] = blizzards[2][idx - 1];
        blizzards[2][0] = last_col;

        const first = blizzards[3][0];
        idx = 0;
        while (idx + 1 < blizzards[3].len) : (idx += 1) blizzards[3][idx] = blizzards[3][idx + 1];
        blizzards[3][blizzards[3].len - 1] = first;
        steps += 1;

        if ((reachable[lenx - 1] & mask_last != 0 and iter % 2 == 0) or (reachable[0] & 1 != 0 and iter % 2 == 1)) {
            @memset(reachable, 0);
            iter += 1;
            if (iter == max_iter) return steps;
            continue;
        }

        var prev: u64 = if (iter % 2 == 0) 1 else 0;
        const last = if (iter % 2 == 1) mask_last else 0;
        x = 0;
        while (x < lenx) : (x += 1) {
            const prev_val = prev;
            prev = reachable[x];
            const next = if (x + 1 < lenx) reachable[x + 1] else last;
            reachable[x] |= (reachable[x] >> 1) | (reachable[x] << 1) | prev_val | next;
            reachable[x] &= blizzards[0][x] & blizzards[1][x] & blizzards[2][x] & blizzards[3][x];
            reachable[x] &= mask_inside;
        }
    }
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const parsed = parse(input, allocator) catch unreachable;
    defer {
        for (parsed.blizzards) |col| allocator.free(col);
    }

    const bliz1: [4][]u64 = .{
        allocator.dupe(u64, parsed.blizzards[0]) catch unreachable,
        allocator.dupe(u64, parsed.blizzards[1]) catch unreachable,
        allocator.dupe(u64, parsed.blizzards[2]) catch unreachable,
        allocator.dupe(u64, parsed.blizzards[3]) catch unreachable,
    };
    defer {
        for (bliz1) |col| allocator.free(col);
    }

    const bliz2: [4][]u64 = .{
        allocator.dupe(u64, parsed.blizzards[0]) catch unreachable,
        allocator.dupe(u64, parsed.blizzards[1]) catch unreachable,
        allocator.dupe(u64, parsed.blizzards[2]) catch unreachable,
        allocator.dupe(u64, parsed.blizzards[3]) catch unreachable,
    };
    defer {
        for (bliz2) |col| allocator.free(col);
    }

    const p1 = solveInner(parsed.lenx, parsed.leny, bliz1, 1);
    const p2 = solveInner(parsed.lenx, parsed.leny, bliz2, 3);
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
