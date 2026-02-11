const std = @import("std");

const Result = struct { p1: i64, p2: i64 };


fn sacc(x: u64, a: u64) u64 {
    const MASK: u64 = 0x5555555555555555;
    return ((x & ~MASK) | (x & MASK) +% a) ^ (a & x & (x >> 1));
}


fn evenBits(grid: u64) u32 {
    var b: u32 = @truncate(grid | (grid >> 31));
    b = (b & 0x99999999) | (b & 0x22222222) << 1 | (b & 0x44444444) >> 1;
    b = (b & 0xc3c3c3c3) | (b & 0x0c0c0c0c) << 2 | (b & 0x30303030) >> 2;
    b = (b & 0xf00ff00f) | (b & 0x00f000f0) << 4 | (b & 0x0f000f00) >> 4;
    b = (b & 0xff0000ff) | (b & 0x0000ff00) << 8 | (b & 0x00ff0000) >> 8;
    return b;
}


fn neighbors4(grid: u64) u64 {
    var n = sacc(grid << 10, grid >> 10);
    n = sacc(n, (grid & 0x0ff3fcff3fcff) << 2);
    n = sacc(n, (grid & 0x3fcff3fcff3fc) >> 2);
    return n;
}


fn lifeOrDeath(grid: u64, n: u64, mask: u64) u64 {
    const survived = grid & (n & ~(n >> 1));
    const born = ~grid & (n ^ (n >> 1));
    return (survived | born) & mask;
}


fn next(grid: u64) u64 {
    return lifeOrDeath(grid, neighbors4(grid), 0x1555555555555);
}


fn next3(inner: u64, grid: u64, outer: u64) u64 {

    const UMASK: u64 = 0x155;
    const DMASK: u64 = UMASK << 40;
    const LMASK: u64 = 0x10040100401;
    const RMASK: u64 = LMASK << 8;


    const IMASK: u64 = 0x404404000;
    const IUDMASK: u64 = 0x400004000;

    var n = neighbors4(grid);


    var oud: u64 = 0;
    var olr: u64 = 0;
    oud |= (@as(u64, @intCast(@as(i64, @bitCast((outer >> 14) & 1)))) *% 0xFFFFFFFFFFFFFFFF) & UMASK;
    oud |= (@as(u64, @intCast(@as(i64, @bitCast((outer >> 34) & 1)))) *% 0xFFFFFFFFFFFFFFFF) & DMASK;
    olr |= (@as(u64, @intCast(@as(i64, @bitCast((outer >> 22) & 1)))) *% 0xFFFFFFFFFFFFFFFF) & LMASK;
    olr |= (@as(u64, @intCast(@as(i64, @bitCast((outer >> 26) & 1)))) *% 0xFFFFFFFFFFFFFFFF) & RMASK;

    n = sacc(n, oud);
    n = sacc(n, olr);


    var iud: u64 = 0;
    var ilr: u64 = 0;
    iud = (inner & UMASK) << 10 | (inner & DMASK) >> 10;
    ilr = (inner & LMASK) << 2 | (inner & RMASK) >> 2;

    n = sacc(n, (iud | ilr) & IMASK);
    n = sacc(n, (iud >> 2 | ilr >> 10) & IMASK);
    n = sacc(n, (iud << 2 | ilr << 10) & IMASK);

    n = sacc(n, ((iud >> 4 & IUDMASK) | ilr >> 20) & IMASK);
    n = sacc(n, ((iud << 4 & IUDMASK) | ilr << 20) & IMASK);

    return lifeOrDeath(grid, n, 0x1555554555555);
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {

    var grid: u64 = 0;
    var b: u64 = 1;

    for (input) |c| {
        switch (c) {
            '#' => {
                grid |= b;
                b <<= 2;
            },
            '.' => {
                b <<= 2;
            },
            else => {},
        }
    }

    var part1: i64 = 0;


    var seen = std.AutoHashMap(u64, void).init(allocator);
    defer seen.deinit();

    var g = grid;
    while (true) {
        const gop = try seen.getOrPut(g);
        if (gop.found_existing) {
            part1 = @intCast(evenBits(g));
            break;
        }
        g = next(g);
    }


    var G = try std.ArrayList(u64).initCapacity(allocator, 250);
    defer G.deinit(allocator);
    var N = try std.ArrayList(u64).initCapacity(allocator, 250);
    defer N.deinit(allocator);

    try G.append(allocator, grid);

    var t: usize = 0;
    while (t < 200 and G.items.len > 0) : (t += 1) {
        var prev: u64 = 0;

        const n0 = next3(0, 0, G.items[0]);
        if (n0 != 0) {
            try N.append(allocator, n0);
        }

        var i: usize = 1;
        while (i < G.items.len) : (i += 1) {
            try N.append(allocator, next3(prev, G.items[i - 1], G.items[i]));
            prev = G.items[i - 1];
        }

        try N.append(allocator, next3(prev, G.items[G.items.len - 1], 0));
        const n_last = next3(G.items[G.items.len - 1], 0, 0);
        if (n_last != 0) {
            try N.append(allocator, n_last);
        }

        const tmp = G;
        G = N;
        N = tmp;
        N.clearRetainingCapacity();
    }


    var part2: i64 = 0;
    for (G.items) |g_item| {
        part2 += @popCount(g_item);
    }

    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, arena.allocator());
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\nPart 2: {}\nTime: {d:.2} microseconds\n", .{result.p1, result.p2, elapsed_us});
}

