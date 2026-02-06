const std = @import("std");

const Result = struct {
    p1: usize,
    p2: []const u8,
};

const Fold = union(enum) {
    Horizontal: i32,
    Vertical: i32,
};

fn foldHorizontal(x: i32, p: [2]i32) [2]i32 {
    return if (p[0] < x) p else .{ 2 * x - p[0], p[1] };
}

fn foldVertical(y: i32, p: [2]i32) [2]i32 {
    return if (p[1] < y) p else .{ p[0], 2 * y - p[1] };
}

fn findSeparator(input: []const u8) struct { pos: usize, len: usize } {
    var i: usize = 0;
    while (i + 1 < input.len) : (i += 1) {
        if (input[i] == '\n' and input[i + 1] == '\n') return .{ .pos = i, .len = 2 };
        if (i + 3 < input.len and input[i] == '\r' and input[i + 1] == '\n' and input[i + 2] == '\r' and input[i + 3] == '\n') {
            return .{ .pos = i, .len = 4 };
        }
    }
    return .{ .pos = input.len, .len = 0 };
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;

    const sep = findSeparator(input);
    const points_section = input[0..sep.pos];
    const folds_section = if (sep.pos + sep.len <= input.len) input[sep.pos + sep.len ..] else input[sep.pos..];

    var value_count: usize = 0;
    var i: usize = 0;
    var in_num = false;
    while (i < points_section.len) : (i += 1) {
        const c = points_section[i];
        if (c >= '0' and c <= '9') {
            if (!in_num) {
                value_count += 1;
                in_num = true;
            }
        } else {
            in_num = false;
        }
    }

    const point_count = value_count / 2;
    const points = allocator.alloc([2]i32, point_count) catch unreachable;
    defer allocator.free(points);

    var p_idx: usize = 0;
    i = 0;
    var value: i32 = 0;
    var values: [2]i32 = undefined;
    var v_idx: usize = 0;
    in_num = false;
    while (i <= points_section.len) : (i += 1) {
        const c = if (i < points_section.len) points_section[i] else '\n';
        if (c >= '0' and c <= '9') {
            value = value * 10 + @as(i32, c - '0');
            in_num = true;
            continue;
        }
        if (in_num) {
            values[v_idx] = value;
            v_idx += 1;
            value = 0;
            in_num = false;
            if (v_idx == 2) {
                points[p_idx] = values;
                p_idx += 1;
                v_idx = 0;
            }
        }
    }

    var fold_count: usize = 0;
    i = 0;
    while (i < folds_section.len) : (i += 1) {
        if (folds_section[i] == '=') fold_count += 1;
    }
    const folds = allocator.alloc(Fold, fold_count) catch unreachable;
    defer allocator.free(folds);

    var f_idx: usize = 0;
    i = 0;
    while (i < folds_section.len) {
        while (i < folds_section.len and folds_section[i] != 'x' and folds_section[i] != 'y') : (i += 1) {}
        if (i >= folds_section.len) break;
        const axis = folds_section[i];
        while (i < folds_section.len and folds_section[i] != '=') : (i += 1) {}
        if (i >= folds_section.len) break;
        i += 1;
        var num: i32 = 0;
        while (i < folds_section.len and folds_section[i] >= '0' and folds_section[i] <= '9') : (i += 1) {
            num = num * 10 + @as(i32, folds_section[i] - '0');
        }
        folds[f_idx] = if (axis == 'x') .{ .Horizontal = num } else .{ .Vertical = num };
        f_idx += 1;
    }

    var p1: usize = 0;
    if (f_idx > 0) {
        var seen = std.AutoHashMap(u32, void).init(allocator);
        defer seen.deinit();
        const first = folds[0];
        var pi: usize = 0;
        while (pi < p_idx) : (pi += 1) {
            const p = points[pi];
            const folded = switch (first) {
                .Horizontal => |x| foldHorizontal(x, p),
                .Vertical => |y| foldVertical(y, p),
            };
            const key = (@as(u32, @intCast(folded[0])) << 16) | @as(u32, @intCast(folded[1]));
            seen.put(key, {}) catch unreachable;
        }
        p1 = seen.count();
    }

    var width: i32 = 0;
    var height: i32 = 0;
    var fi: usize = 0;
    while (fi < f_idx) : (fi += 1) {
        switch (folds[fi]) {
            .Horizontal => |x| width = x,
            .Vertical => |y| height = y,
        }
    }

    const grid_w = @as(usize, @intCast(width + 1));
    const grid_h = @as(usize, @intCast(height));
    const out_len = grid_h * (grid_w + 1);
    var output = allocator.alloc(u8, out_len) catch unreachable;
    for (output) |*b| b.* = '.';

    var row: usize = 0;
    while (row < grid_h) : (row += 1) {
        output[row * (grid_w + 1)] = '\n';
    }

    var pt: usize = 0;
    while (pt < p_idx) : (pt += 1) {
        var p = points[pt];
        fi = 0;
        while (fi < f_idx) : (fi += 1) {
            p = switch (folds[fi]) {
                .Horizontal => |x| foldHorizontal(x, p),
                .Vertical => |y| foldVertical(y, p),
            };
        }
        const x = @as(usize, @intCast(p[0] + 1));
        const y = @as(usize, @intCast(p[1]));
        output[y * (grid_w + 1) + x] = '#';
    }

    return .{ .p1 = p1, .p2 = output };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2:{s}", .{result.p2});
    std.debug.print("\nTime: {d:.2} microseconds\n", .{elapsed_us});
}
