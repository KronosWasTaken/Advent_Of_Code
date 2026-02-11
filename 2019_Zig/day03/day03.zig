const std = @import("std");

const Result = struct {
    p1: i32,
    p2: i32,
};

const Segment = packed struct {
    fixed: i32,
    min_other: i32,
    max_other: i32,
    distance: i32,
    is_negative: bool,
};

const Wire = struct {
    horizontal: []Segment,
    vertical: []Segment,
};

fn parseWire(wire_str: []const u8, allocator: std.mem.Allocator) !Wire {
    var h_buf: [300]Segment = undefined;
    var v_buf: [300]Segment = undefined;
    var h_count: usize = 0;
    var v_count: usize = 0;

    var x: i32 = 0;
    var y: i32 = 0;
    var distance: i32 = 0;
    var num: i32 = 0;
    var dir: u8 = 0;

    for (wire_str) |c| {
        if (c >= '0' and c <= '9') {
            num = num * 10 + (c - '0');
        } else if (c >= 'A' and c <= 'Z') {
            dir = c;
        } else if (c == ',' or c == '\n' or c == '\r') {
            if (num > 0) {
                const is_negative = dir == 'L' or dir == 'D';
                if (dir == 'U' or dir == 'D') {
                    const new_y = if (dir == 'U') y + num else y - num;
                    const min_y = if (y < new_y) y else new_y;
                    const max_y = if (y < new_y) new_y else y;
                    v_buf[v_count] = Segment{
                        .fixed = x,
                        .min_other = min_y,
                        .max_other = max_y,
                        .distance = distance,
                        .is_negative = is_negative,
                    };
                    v_count += 1;
                    y = new_y;
                } else {
                    const new_x = if (dir == 'R') x + num else x - num;
                    const min_x = if (x < new_x) x else new_x;
                    const max_x = if (x < new_x) new_x else x;
                    h_buf[h_count] = Segment{
                        .fixed = y,
                        .min_other = min_x,
                        .max_other = max_x,
                        .distance = distance,
                        .is_negative = is_negative,
                    };
                    h_count += 1;
                    x = new_x;
                }
                distance += num;
                num = 0;
            }
        }
    }

    const h_slice = try allocator.dupe(Segment, h_buf[0..h_count]);
    const v_slice = try allocator.dupe(Segment, v_buf[0..v_count]);

    return Wire{
        .horizontal = h_slice,
        .vertical = v_slice,
    };
}

inline fn updateResults(ix: i32, iy: i32, s1_dist: i32, s2_dist: i32, s1: i32, s2: i32, part1: *i32, part2: *i32) void {
    const abs_x = if (ix < 0) -ix else ix;
    const abs_y = if (iy < 0) -iy else iy;
    const dist = abs_x + abs_y;
    if (dist < part1.*) part1.* = dist;

    const total_steps = s1_dist + s1 + s2_dist + s2;
    if (total_steps < part2.*) part2.* = total_steps;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var lines = std.mem.splitSequence(u8, input, "\n");
    const line1_str = lines.next() orelse return Result{ .p1 = 0, .p2 = 0 };
    const line2_str = lines.next() orelse return Result{ .p1 = 0, .p2 = 0 };

    const wire1 = try parseWire(line1_str, allocator);
    defer allocator.free(wire1.horizontal);
    defer allocator.free(wire1.vertical);

    const wire2 = try parseWire(line2_str, allocator);
    defer allocator.free(wire2.horizontal);
    defer allocator.free(wire2.vertical);

    var part1: i32 = 2147483647;
    var part2: i32 = 2147483647;


    for (wire1.horizontal) |h_seg| {
        for (wire2.vertical) |v_seg| {
            const ix = v_seg.fixed;
            const iy = h_seg.fixed;


            if ((ix | iy) == 0) continue;


            if (v_seg.min_other > iy or iy > v_seg.max_other) continue;
            if (h_seg.min_other > ix or ix > h_seg.max_other) continue;

            const h_dist = if (h_seg.is_negative) (h_seg.max_other - ix) else (ix - h_seg.min_other);
            const v_dist = if (v_seg.is_negative) (v_seg.max_other - iy) else (iy - v_seg.min_other);
            updateResults(ix, iy, h_seg.distance, v_seg.distance, h_dist, v_dist, &part1, &part2);
        }
    }

    for (wire1.vertical) |v_seg| {
        for (wire2.horizontal) |h_seg| {
            const ix = v_seg.fixed;
            const iy = h_seg.fixed;


            if ((ix | iy) == 0) continue;


            if (h_seg.min_other > ix or ix > h_seg.max_other) continue;
            if (v_seg.min_other > iy or iy > v_seg.max_other) continue;

            const v_dist = if (v_seg.is_negative) (v_seg.max_other - iy) else (iy - v_seg.min_other);
            const h_dist = if (h_seg.is_negative) (h_seg.max_other - ix) else (ix - h_seg.min_other);
            updateResults(ix, iy, v_seg.distance, h_seg.distance, v_dist, h_dist, &part1, &part2);
        }
    }

    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, arena.allocator());
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
