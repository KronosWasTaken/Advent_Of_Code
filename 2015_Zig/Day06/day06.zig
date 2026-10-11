const std = @import("std");

const Inst = struct {
    op: u2, // 0 = on, 1 = off, 2 = toggle
    x1: u16,
    x2: u16,
    y1: u16,
    y2: u16,
};


const V = @Vector(32, u8);
const v_one: V = @splat(1);
const v_two: V = @splat(2);

fn runPart1Bitset(insts: []const Inst) u32 {
    @setRuntimeSafety(false);
    var grid: [1000][16]u64 = [_][16]u64{[_]u64{0} ** 16} ** 1000;

    for (insts) |inst| {
        const w1 = inst.x1 >> 6;
        const b1: u6 = @truncate(inst.x1);
        const w2 = inst.x2 >> 6;
        const b2: u6 = @truncate(inst.x2);

        if (w1 == w2) {
            const mask: u64 = ((@as(u64, 2) << b2) -% 1) ^ ((@as(u64, 1) << b1) -% 1);
            switch (inst.op) {
                0 => for (inst.y1..inst.y2 + 1) |y| { grid[y][w1] |= mask; },
                1 => for (inst.y1..inst.y2 + 1) |y| { grid[y][w1] &= ~mask; },
                2 => for (inst.y1..inst.y2 + 1) |y| { grid[y][w1] ^= mask; },
                else => unreachable,
            }
        } else {
            const mask_first: u64 = ~((@as(u64, 1) << b1) -% 1);
            const mask_last: u64 = (@as(u64, 2) << b2) -% 1;
            switch (inst.op) {
                0 => for (inst.y1..inst.y2 + 1) |y| {
                    grid[y][w1] |= mask_first;
                    for (w1 + 1..w2) |w| grid[y][w] = ~@as(u64, 0);
                    grid[y][w2] |= mask_last;
                },
                1 => for (inst.y1..inst.y2 + 1) |y| {
                    grid[y][w1] &= ~mask_first;
                    for (w1 + 1..w2) |w| grid[y][w] = 0;
                    grid[y][w2] &= ~mask_last;
                },
                2 => for (inst.y1..inst.y2 + 1) |y| {
                    grid[y][w1] ^= mask_first;
                    for (w1 + 1..w2) |w| grid[y][w] ^= ~@as(u64, 0);
                    grid[y][w2] ^= mask_last;
                },
                else => unreachable,
            }
        }
    }

    var total: u32 = 0;
    for (0..1000) |y| {
        for (0..16) |w| {
            total += @popCount(grid[y][w]);
        }
    }
    return total;
}

const Part2WorkerData = struct {
    grid: *[1000][1024]u8,
    insts: []const Inst,
    y_start: usize,
    y_end: usize,
    total: u32 = 0,
};

fn part2Worker(data: *Part2WorkerData) void {
    @setRuntimeSafety(false);
    const grid = data.grid;
    const y_start = data.y_start;
    const y_end = data.y_end;

    for (data.insts) |inst| {
        if (inst.y2 < y_start or inst.y1 > y_end) continue;
        const cur_y1 = @max(inst.y1, y_start);
        const cur_y2 = @min(inst.y2, y_end);

        const x1 = inst.x1;
        const x2 = inst.x2 + 1;
        const aligned_start = @min(x2, (x1 + 31) & ~@as(usize, 31));

        switch (inst.op) {
            0 => {
                for (cur_y1..cur_y2 + 1) |y| {
                    var x = x1;
                    while (x < aligned_start) : (x += 1) grid[y][x] += 1;
                    while (x + 128 <= x2) : (x += 128) {
                        const ptr0: *align(32) V = @ptrCast(@alignCast(&grid[y][x]));
                        const ptr1: *align(32) V = @ptrCast(@alignCast(&grid[y][x + 32]));
                        const ptr2: *align(32) V = @ptrCast(@alignCast(&grid[y][x + 64]));
                        const ptr3: *align(32) V = @ptrCast(@alignCast(&grid[y][x + 96]));
                        ptr0.* += v_one;
                        ptr1.* += v_one;
                        ptr2.* += v_one;
                        ptr3.* += v_one;
                    }
                    while (x + 32 <= x2) : (x += 32) {
                        const ptr: *align(32) V = @ptrCast(@alignCast(&grid[y][x]));
                        ptr.* += v_one;
                    }
                    while (x < x2) : (x += 1) grid[y][x] += 1;
                }
            },
            1 => {
                for (cur_y1..cur_y2 + 1) |y| {
                    var x = x1;
                    while (x < aligned_start) : (x += 1) grid[y][x] -|= 1;
                    while (x + 128 <= x2) : (x += 128) {
                        const ptr0: *align(32) V = @ptrCast(@alignCast(&grid[y][x]));
                        const ptr1: *align(32) V = @ptrCast(@alignCast(&grid[y][x + 32]));
                        const ptr2: *align(32) V = @ptrCast(@alignCast(&grid[y][x + 64]));
                        const ptr3: *align(32) V = @ptrCast(@alignCast(&grid[y][x + 96]));
                        ptr0.* = ptr0.* -| v_one;
                        ptr1.* = ptr1.* -| v_one;
                        ptr2.* = ptr2.* -| v_one;
                        ptr3.* = ptr3.* -| v_one;
                    }
                    while (x + 32 <= x2) : (x += 32) {
                        const ptr: *align(32) V = @ptrCast(@alignCast(&grid[y][x]));
                        ptr.* = ptr.* -| v_one;
                    }
                    while (x < x2) : (x += 1) grid[y][x] -|= 1;
                }
            },
            2 => {
                for (cur_y1..cur_y2 + 1) |y| {
                    var x = x1;
                    while (x < aligned_start) : (x += 1) grid[y][x] += 2;
                    while (x + 128 <= x2) : (x += 128) {
                        const ptr0: *align(32) V = @ptrCast(@alignCast(&grid[y][x]));
                        const ptr1: *align(32) V = @ptrCast(@alignCast(&grid[y][x + 32]));
                        const ptr2: *align(32) V = @ptrCast(@alignCast(&grid[y][x + 64]));
                        const ptr3: *align(32) V = @ptrCast(@alignCast(&grid[y][x + 96]));
                        ptr0.* += v_two;
                        ptr1.* += v_two;
                        ptr2.* += v_two;
                        ptr3.* += v_two;
                    }
                    while (x + 32 <= x2) : (x += 32) {
                        const ptr: *align(32) V = @ptrCast(@alignCast(&grid[y][x]));
                        ptr.* += v_two;
                    }
                    while (x < x2) : (x += 1) grid[y][x] += 2;
                }
            },
            else => unreachable,
        }
    }

    var total: u32 = 0;
    const Vec32 = @Vector(32, u8);
    for (y_start..y_end + 1) |y| {
        var x: usize = 0;
        while (x < 1000) : (x += 32) {
            const v: Vec32 = grid[y][x..][0..32].*;
            total += @reduce(.Add, @as(@Vector(32, u32), v));
        }
    }
    data.total = total;
}

inline fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var insts: [512]Inst = undefined;
    var inst_count: usize = 0;

    var i: usize = 0;
    while (i < input.len) {
        if (input[i] != 't') break;
        const op: u2 = if (input[i + 6] == 'n') 0 else if (input[i + 6] == 'f') 1 else 2;
        i += if (op == 0) 8 else if (op == 1) 9 else 7;

        var x1: u16 = 0;
        while (input[i] != ',') : (i += 1) x1 = x1 * 10 + (input[i] - '0');
        i += 1;
        var y1: u16 = 0;
        while (input[i] != ' ') : (i += 1) y1 = y1 * 10 + (input[i] - '0');
        i += 9;
        var x2: u16 = 0;
        while (input[i] != ',') : (i += 1) x2 = x2 * 10 + (input[i] - '0');
        i += 1;
        var y2: u16 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) y2 = y2 * 10 + (input[i] - '0');
        while (i < input.len and (input[i] == '\n' or input[i] == '\r')) : (i += 1) {}

        insts[inst_count] = .{
            .op = op,
            .x1 = x1,
            .x2 = x2,
            .y1 = y1,
            .y2 = y2,
        };
        inst_count += 1;
    }

    var grid2: [1000][1024]u8 align(32) = [_][1024]u8{[_]u8{0} ** 1024} ** 1000;
    var d2: Part2WorkerData = .{
        .grid = &grid2,
        .insts = insts[0..inst_count],
        .y_start = 500,
        .y_end = 999,
    };
    const t2 = std.Thread.spawn(.{}, part2Worker, .{&d2}) catch unreachable;

    const p1 = runPart1Bitset(insts[0..inst_count]);

    var d1: Part2WorkerData = .{
        .grid = &grid2,
        .insts = insts[0..inst_count],
        .y_start = 0,
        .y_end = 499,
    };
    part2Worker(&d1);
    t2.join();

    return .{ .p1 = p1, .p2 = d1.total + d2.total };
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
