const std = @import("std");

const Deer = struct {
    spd: u16,
    fly: u16,
    rest: u16,
};

inline fn traveled(spd: u32, fly: u32, rest: u32, time: u32) u32 {
    const cycle = fly + rest;
    const complete = time / cycle;
    const partial = @min(time % cycle, fly);
    return spd * (fly * complete + partial);
}

inline fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var spd_arr = [_]u16{0} ** 16;
    var fly_arr = [_]u16{0} ** 16;
    var rest_arr = [_]u16{0} ** 16;
    var n: usize = 0;

    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and (input[i] < '0' or input[i] > '9')) : (i += 1) {}
        if (i >= input.len) break;
        var spd: u16 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            spd = spd * 10 + @as(u16, input[i] - '0');
        }

        while (i < input.len and (input[i] < '0' or input[i] > '9')) : (i += 1) {}
        var fly: u16 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            fly = fly * 10 + @as(u16, input[i] - '0');
        }

        while (i < input.len and (input[i] < '0' or input[i] > '9')) : (i += 1) {}
        var rest: u16 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            rest = rest * 10 + @as(u16, input[i] - '0');
        }

        spd_arr[n] = spd;
        fly_arr[n] = fly;
        rest_arr[n] = rest;
        n += 1;
        while (i < input.len and input[i] != '\n') : (i += 1) {}
    }

    // Part 1: Closed-form formula
    var p1: u32 = 0;
    for (0..n) |d| {
        p1 = @max(p1, traveled(spd_arr[d], fly_arr[d], rest_arr[d], 2503));
    }

    // Part 2: Vectorized simulation
    const Vec = @Vector(16, u16);
    const spd_vec: Vec = spd_arr;
    const fly_vec: Vec = fly_arr;
    const rest_vec: Vec = rest_arr;

    // Each reindeer's second within its fly + rest cycle: it flies while that is below `fly`.
    // A wrapping counter needs no branch and keeps the per-second dependency chain short.
    // Unused lanes have a zero cycle, so they never wrap, never fly and never lead.
    const cycle_vec = fly_vec + rest_vec;
    var phase: Vec = @splat(0);
    var dist: Vec = @splat(0);
    var scores: Vec = @splat(0);
    const ones: Vec = @splat(1);
    const zeros: Vec = @splat(0);

    for (0..2503) |_| {
        dist += @select(u16, phase < fly_vec, spd_vec, zeros);
        phase += ones;
        phase = @select(u16, phase == cycle_vec, zeros, phase);

        // Leader scores a point
        const max_dist = @reduce(.Max, dist);
        const is_leader = dist == @as(Vec, @splat(max_dist));
        scores += @select(u16, is_leader, ones, zeros);
    }

    const p2: u32 = @reduce(.Max, scores);

    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
