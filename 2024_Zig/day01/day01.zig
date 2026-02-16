const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

const N: usize = 1000;

fn parse5(bytes: []const u8) u32 {
    const b0 = @as(u32, bytes[0]);
    const b1 = @as(u32, bytes[1]);
    const b2 = @as(u32, bytes[2]);
    const b3 = @as(u32, bytes[3]);
    const b4 = @as(u32, bytes[4]);
    return (b0 * 10000 + b1 * 1000 + b2 * 100 + b3 * 10 + b4) - 533328;
}

fn radixSortU17(arr: *[N]u32) void {
    var cnt_lo: [256]u16 = [_]u16{0} ** 256;
    var cnt_hi: [512]u16 = [_]u16{0} ** 512;

    for (arr) |value| {
        cnt_lo[value & 0xFF] += 1;
        cnt_hi[value >> 8] += 1;
    }

    var sum: u16 = 0;
    for (&cnt_lo) |*count| {
        const temp = count.*;
        count.* = sum;
        sum += temp;
    }
    sum = 0;
    for (&cnt_hi) |*count| {
        const temp = count.*;
        count.* = sum;
        sum += temp;
    }

    var buf: [N]u32 = undefined;
    for (arr) |value| {
        const idx = value & 0xFF;
        const dest = &cnt_lo[idx];
        buf[dest.*] = value;
        dest.* += 1;
    }

    for (buf) |value| {
        const idx = value >> 8;
        const dest = &cnt_hi[idx];
        arr[dest.*] = value;
        dest.* += 1;
    }
}

fn solve(input: []const u8) Result {
    var left: [N]u32 = undefined;
    var right: [N]u32 = undefined;

    const newline = std.mem.indexOfScalar(u8, input, '\n') orelse input.len;
    const line_len = if (newline > 0 and input[newline - 1] == '\r') newline + 1 else newline + 1;

    var i: usize = 0;
    while (i < N) : (i += 1) {
        const base = i * line_len;
        left[i] = parse5(input[base .. base + 5]);
        right[i] = parse5(input[base + 8 .. base + 13]);
    }

    radixSortU17(&left);
    radixSortU17(&right);

    var part_one: u32 = 0;
    for (left, right) |l, r| {
        part_one += if (l >= r) l - r else r - l;
    }

    var assoc: [2048]u32 = [_]u32{0} ** 2048;
    for (right) |value| {
        var h: usize = value & 2047;
        while (true) {
            const entry = &assoc[h];
            if (entry.* == 0) {
                entry.* = value | (1 << 20);
                break;
            }
            if ((entry.* & 0xFFFFF) == value) {
                entry.* += 1 << 20;
                break;
            }
            h = (h + 1) & 2047;
        }
    }

    var part_two: u32 = 0;
    for (left) |value| {
        var h: usize = value & 2047;
        while (true) {
            const entry = assoc[h];
            if (entry == 0) break;
            if ((entry & 0xFFFFF) == value) {
                part_two += value * (entry >> 20);
                break;
            }
            h = (h + 1) & 2047;
        }
    }

    return Result{ .p1 = part_one, .p2 = part_two };
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
