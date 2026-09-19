const std = @import("std");

const Result = struct { p1: u32, p2: u32 };

const Input = struct {
    algo: []u8,
    grid: []u8,
    width: i32,
    height: i32,
};

const LaneWidth = 16;
const Vec = @Vector(LaneWidth, u16);

fn normalize(input: []const u8, allocator: std.mem.Allocator) []u8 {
    var out = std.ArrayListUnmanaged(u8){};
    out.ensureTotalCapacity(allocator, input.len) catch unreachable;
    for (input) |c| if (c != '\r') out.append(allocator, c) catch unreachable;
    return out.toOwnedSlice(allocator) catch unreachable;
}

fn parse(input: []const u8, allocator: std.mem.Allocator) Input {
    const normalized = normalize(input, allocator);
    defer allocator.free(normalized);

    var split_iter = std.mem.splitSequence(u8, normalized, "\n\n");
    const prefix = split_iter.next().?;
    const suffix = split_iter.next() orelse "";

    const algo = allocator.alloc(u8, prefix.len) catch unreachable;
    for (prefix, 0..) |c, i| algo[i] = @intFromBool(c == '#');

    var width: i32 = 0;
    while (width < suffix.len and suffix[@as(usize, @intCast(width))] != '\n') : (width += 1) {}
    var height: i32 = 0;
    for (suffix) |c| {
        if (c == '\n') height += 1;
    }
    if (suffix.len > 0 and suffix[suffix.len - 1] != '\n') height += 1;

    const grid = allocator.alloc(u8, @as(usize, @intCast(width * height))) catch unreachable;
    var idx: usize = 0;
    for (suffix) |c| {
        if (c == '#' or c == '.') {
            grid[idx] = @intFromBool(c == '#');
            idx += 1;
        }
    }

    return .{ .algo = algo, .grid = grid, .width = width, .height = height };
}

fn fillRowCodes(pixels: []const u8, out_w: i32, y: i32, lo: i32, hi: i32, valid_lo: i32, valid_hi: i32, default: u8, dst: []u16) void {
    const y_valid = y >= valid_lo and y < valid_hi;
    var x: i32 = lo;
    while (x < hi) : (x += 1) {
        const self_val: u16 = if (!y_valid or x < valid_lo or x >= valid_hi) default else pixels[@as(usize, @intCast(y * out_w + x))];
        const left_x = x - 1;
        const left_val: u16 = if (!y_valid or left_x < valid_lo or left_x >= valid_hi) default else pixels[@as(usize, @intCast(y * out_w + left_x))];
        const right_x = x + 1;
        const right_val: u16 = if (!y_valid or right_x < valid_lo or right_x >= valid_hi) default else pixels[@as(usize, @intCast(y * out_w + right_x))];
        dst[@as(usize, @intCast(x - lo))] = (left_val << 2) | (self_val << 1) | right_val;
    }
}

fn enhanceSimd(input: Input, steps: i32, allocator: std.mem.Allocator) u32 {
    const extra = steps + 1;
    const out_w = input.width + 2 * extra + LaneWidth;
    const out_h = input.height + 2 * extra;
    const size = @as(usize, @intCast(out_w * out_h));

    var pixels = allocator.alloc(u8, size) catch unreachable;
    var next = allocator.alloc(u8, size) catch unreachable;
    defer allocator.free(pixels);
    defer allocator.free(next);
    @memset(pixels, 0);
    @memset(next, 0);

    var y: i32 = 0;
    while (y < input.height) : (y += 1) {
        var x: i32 = 0;
        while (x < input.width) : (x += 1) {
            const src = @as(usize, @intCast(y * input.width + x));
            const dst = @as(usize, @intCast((y + extra) * out_w + (x + extra)));
            pixels[dst] = input.grid[src];
        }
    }

    var default: u8 = 0;
    var start: i32 = extra - 1;
    var end: i32 = extra + input.width + 1;

    const left_mask: Vec = @splat(0b110);
    const mid_mask: Vec = @splat(3);

    var row_above = allocator.alloc(u16, @as(usize, @intCast(out_w))) catch unreachable;
    var row_mid = allocator.alloc(u16, @as(usize, @intCast(out_w))) catch unreachable;
    var row_below = allocator.alloc(u16, @as(usize, @intCast(out_w))) catch unreachable;
    defer allocator.free(row_above);
    defer allocator.free(row_mid);
    defer allocator.free(row_below);

    var step: i32 = 0;
    while (step < steps) : (step += 1) {
        const lo = start - 1;
        const hi = end;
        const valid_lo = lo + 1;
        const valid_hi = hi - 1;

        fillRowCodes(pixels, out_w, lo - 1, lo, hi, valid_lo, valid_hi, default, row_mid);
        fillRowCodes(pixels, out_w, lo, lo, hi, valid_lo, valid_hi, default, row_below);

        var row: i32 = lo;
        while (row < hi) : (row += 1) {
            const tmp = row_above;
            row_above = row_mid;
            row_mid = row_below;
            row_below = tmp;
            fillRowCodes(pixels, out_w, row + 1, lo, hi, valid_lo, valid_hi, default, row_below);

            var x: i32 = lo;
            while (x < hi) : (x += LaneWidth) {
                const off = @as(usize, @intCast(x - lo));
                const above: Vec = row_above[off..][0..LaneWidth].*;
                const mid: Vec = row_mid[off..][0..LaneWidth].*;
                const below: Vec = row_below[off..][0..LaneWidth].*;
                const indices = (above << left_mask) | (mid << mid_mask) | below;

                const base = @as(usize, @intCast(out_w * row + x));
                const idx_array = @as([LaneWidth]u16, indices);
                var i: usize = 0;
                while (i < LaneWidth and x + @as(i32, @intCast(i)) < hi) : (i += 1) {
                    next[base + i] = input.algo[idx_array[i]];
                }
            }
        }

        std.mem.swap([]u8, &pixels, &next);
        default = if (default == 0) input.algo[0] else input.algo[511];
        start -= 1;
        end += 1;
    }

    var sum: u32 = 0;
    var yy: i32 = 1;
    while (yy < end - 1) : (yy += 1) {
        var xx: i32 = 1;
        while (xx < end - 1) : (xx += 1) {
            sum += pixels[@as(usize, @intCast(yy * out_w + xx))];
        }
    }
    return sum;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const parsed = parse(input, allocator);
    defer allocator.free(parsed.algo);
    defer allocator.free(parsed.grid);

    const p1 = enhanceSimd(parsed, 2, allocator);
    const p2 = enhanceSimd(parsed, 50, allocator);
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
