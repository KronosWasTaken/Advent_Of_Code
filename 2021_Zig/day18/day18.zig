const std = @import("std");

const Result = struct {
    p1: i32,
    p2: i32,
};

const Snailfish = [63]i32;

const IN_ORDER = [_]usize{
    1, 3, 7, 15, 16, 8, 17, 18, 4, 9, 19, 20, 10, 21, 22, 2, 5, 11, 23, 24, 12, 25, 26, 6, 13, 27, 28, 14, 29, 30,
};

fn parseLine(bytes: []const u8) Snailfish {
    var tree: Snailfish = [_]i32{-1} ** 63;
    var i: usize = 0;
    for (bytes) |b| {
        switch (b) {
            '[' => i = 2 * i + 1,
            ',' => i += 1,
            ']' => i = (i - 1) / 2,
            else => tree[i] = @as(i32, b - '0'),
        }
    }
    return tree;
}

fn explode(tree: *Snailfish, pair: usize) void {
    if (pair > 31) {
        var i = pair - 1;
        while (true) {
            if (tree.*[i] >= 0) {
                tree.*[i] += tree.*[pair];
                break;
            }
            i = (i - 1) / 2;
        }
    }
    if (pair < 61) {
        var i = pair + 2;
        while (true) {
            if (tree.*[i] >= 0) {
                tree.*[i] += tree.*[pair + 1];
                break;
            }
            i = (i - 1) / 2;
        }
    }
    tree.*[pair] = -1;
    tree.*[pair + 1] = -1;
    tree.*[(pair - 1) / 2] = 0;
}

fn split(tree: *Snailfish) bool {
    inline for (IN_ORDER) |i| {
        if (tree.*[i] >= 10) {
            tree.*[2 * i + 1] = @divTrunc(tree.*[i], 2);
            tree.*[2 * i + 2] = @divTrunc(tree.*[i] + 1, 2);
            tree.*[i] = -1;
            if (i >= 15) explode(tree, 2 * i + 1);
            return true;
        }
    }
    return false;
}

fn add(left: *const Snailfish, right: *const Snailfish) Snailfish {
    var tree: Snailfish = [_]i32{-1} ** 63;

    std.mem.copyForwards(i32, tree[3..5], left[1..3]);
    std.mem.copyForwards(i32, tree[7..11], left[3..7]);
    std.mem.copyForwards(i32, tree[15..23], left[7..15]);
    std.mem.copyForwards(i32, tree[31..47], left[15..31]);

    std.mem.copyForwards(i32, tree[5..7], right[1..3]);
    std.mem.copyForwards(i32, tree[11..15], right[3..7]);
    std.mem.copyForwards(i32, tree[23..31], right[7..15]);
    std.mem.copyForwards(i32, tree[47..63], right[15..31]);

    var pair: usize = 31;
    while (pair < 63) : (pair += 2) {
        if (tree[pair] >= 0) explode(&tree, pair);
    }

    while (split(&tree)) {}
    return tree;
}

fn magnitude(tree: *Snailfish) i32 {
    var i: usize = 31;
    while (true) {
        i -= 1;
        if (tree.*[i] == -1) tree.*[i] = 3 * tree.*[2 * i + 1] + 2 * tree.*[2 * i + 2];
        if (i == 0) break;
    }
    return tree.*[0];
}

fn solve(input: []const u8) Result {
    @setRuntimeSafety(false);
    const allocator = std.heap.page_allocator;
    var count: usize = 0;
    for (input) |c| {
        if (c == '\n') count += 1;
    }
    if (input.len > 0 and input[input.len - 1] != '\n') count += 1;

    const list = allocator.alloc(Snailfish, count) catch unreachable;
    defer allocator.free(list);

    var idx: usize = 0;
    var start: usize = 0;
    var i: usize = 0;
    while (i <= input.len) : (i += 1) {
        if (i == input.len or input[i] == '\n') {
            var end = i;
            if (end > start and input[end - 1] == '\r') end -= 1;
            if (end > start) {
                list[idx] = parseLine(input[start..end]);
                idx += 1;
            }
            start = i + 1;
        }
    }

    var sum = list[0];
    var j: usize = 1;
    while (j < idx) : (j += 1) {
        sum = add(&sum, &list[j]);
    }
    const p1 = magnitude(&sum);

    var best: i32 = 0;
    var a: usize = 0;
    while (a < idx) : (a += 1) {
        var b: usize = 0;
        while (b < idx) : (b += 1) {
            if (a == b) continue;
            var temp = add(&list[a], &list[b]);
            const value = magnitude(&temp);
            if (value > best) best = value;
        }
    }

    return .{ .p1 = p1, .p2 = best };
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
