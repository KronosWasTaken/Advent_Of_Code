const std = @import("std");

const Result = struct {
    p1: u32,

    p2: u32,
};

const RowMasks = struct {
    x: [3]u64,

    m: [3]u64,

    a: [3]u64,

    s: [3]u64,
};

fn shiftLeft(m: [3]u64, shift: u6, mask_last: u64) [3]u64 {
    if (shift == 0) return m;

    const inv: u6 = @intCast(64 - @as(u7, shift));

    const r0 = m[0] << shift;

    const r1 = (m[1] << shift) | (m[0] >> inv);

    const r2 = ((m[2] << shift) | (m[1] >> inv)) & mask_last;

    return .{ r0, r1, r2 };
}

fn shiftRight(m: [3]u64, shift: u6, mask_last: u64) [3]u64 {
    if (shift == 0) return m;

    const inv: u6 = @intCast(64 - @as(u7, shift));
    const r2 = m[2] >> shift;
    const r1 = (m[1] >> shift) | (m[2] << inv);
    const r0 = (m[0] >> shift) | (m[1] << inv);
    return .{ r0, r1, r2 & mask_last };
}

fn countBits(m: [3]u64) u32 {
    return @popCount(m[0]) + @popCount(m[1]) + @popCount(m[2]);
}

fn solve(input: []const u8) Result {
    const line_end = std.mem.indexOfScalar(u8, input, '\n') orelse 0;

    var width = line_end;

    var stride = line_end + 1;

    if (line_end > 0 and input[line_end - 1] == '\r') {
        width = line_end - 1;

        stride = line_end + 1;
    }

    const height = if (stride > 0) input.len / stride else 0;

    const mask_last: u64 = if (width % 64 == 0) ~@as(u64, 0) else (@as(u64, 1) << @intCast(width % 64)) - 1;

    const allocator = std.heap.page_allocator;

    var rows: std.ArrayListUnmanaged(RowMasks) = .{};

    defer rows.deinit(allocator);

    rows.ensureTotalCapacity(allocator, height) catch unreachable;

    for (0..height) |y| {
        var row = RowMasks{ .x = .{ 0, 0, 0 }, .m = .{ 0, 0, 0 }, .a = .{ 0, 0, 0 }, .s = .{ 0, 0, 0 } };

        const base = y * stride;

        for (0..width) |x| {
            const ch = input[base + x];

            const bit = @as(u64, 1) << @intCast(x & 63);

            const idx = x >> 6;

            switch (ch) {
                'X' => row.x[idx] |= bit,

                'M' => row.m[idx] |= bit,

                'A' => row.a[idx] |= bit,

                'S' => row.s[idx] |= bit,

                else => {},
            }
        }

        row.x[2] &= mask_last;

        row.m[2] &= mask_last;

        row.a[2] &= mask_last;

        row.s[2] &= mask_last;

        rows.appendAssumeCapacity(row);
    }

    var p1: u32 = 0;

    for (rows.items) |row| {
        const m1 = shiftLeft(row.m, 1, mask_last);

        const a2 = shiftLeft(row.a, 2, mask_last);

        const s3 = shiftLeft(row.s, 3, mask_last);

        const t1 = .{ row.x[0] & m1[0] & a2[0] & s3[0], row.x[1] & m1[1] & a2[1] & s3[1], row.x[2] & m1[2] & a2[2] & s3[2] };

        const a1 = shiftLeft(row.a, 1, mask_last);

        const m2 = shiftLeft(row.m, 2, mask_last);

        const x3 = shiftLeft(row.x, 3, mask_last);

        const t2 = .{ row.s[0] & a1[0] & m2[0] & x3[0], row.s[1] & a1[1] & m2[1] & x3[1], row.s[2] & a1[2] & m2[2] & x3[2] };

        p1 += countBits(t1) + countBits(t2);
    }

    if (height >= 4) {
        for (0..height - 3) |y| {
            const r0 = rows.items[y];

            const r1 = rows.items[y + 1];

            const r2 = rows.items[y + 2];

            const r3 = rows.items[y + 3];

            const v1 = .{ r0.x[0] & r1.m[0] & r2.a[0] & r3.s[0], r0.x[1] & r1.m[1] & r2.a[1] & r3.s[1], r0.x[2] & r1.m[2] & r2.a[2] & r3.s[2] };

            const v2 = .{ r0.s[0] & r1.a[0] & r2.m[0] & r3.x[0], r0.s[1] & r1.a[1] & r2.m[1] & r3.x[1], r0.s[2] & r1.a[2] & r2.m[2] & r3.x[2] };

            p1 += countBits(v1) + countBits(v2);

            const dr1 = shiftRight(r1.m, 1, mask_last);

            const dr2 = shiftRight(r2.a, 2, mask_last);

            const dr3 = shiftRight(r3.s, 3, mask_last);

            const dd1 = .{ r0.x[0] & dr1[0] & dr2[0] & dr3[0], r0.x[1] & dr1[1] & dr2[1] & dr3[1], r0.x[2] & dr1[2] & dr2[2] & dr3[2] };

            const dr1s = shiftRight(r1.a, 1, mask_last);

            const dr2s = shiftRight(r2.m, 2, mask_last);

            const dr3s = shiftRight(r3.x, 3, mask_last);

            const dd2 = .{ r0.s[0] & dr1s[0] & dr2s[0] & dr3s[0], r0.s[1] & dr1s[1] & dr2s[1] & dr3s[1], r0.s[2] & dr1s[2] & dr2s[2] & dr3s[2] };

            p1 += countBits(dd1) + countBits(dd2);

            const dl1 = shiftLeft(r1.m, 1, mask_last);

            const dl2 = shiftLeft(r2.a, 2, mask_last);

            const dl3 = shiftLeft(r3.s, 3, mask_last);

            const du1 = .{ r0.x[0] & dl1[0] & dl2[0] & dl3[0], r0.x[1] & dl1[1] & dl2[1] & dl3[1], r0.x[2] & dl1[2] & dl2[2] & dl3[2] };

            const dl1s = shiftLeft(r1.a, 1, mask_last);

            const dl2s = shiftLeft(r2.m, 2, mask_last);

            const dl3s = shiftLeft(r3.x, 3, mask_last);

            const du2 = .{ r0.s[0] & dl1s[0] & dl2s[0] & dl3s[0], r0.s[1] & dl1s[1] & dl2s[1] & dl3s[1], r0.s[2] & dl1s[2] & dl2s[2] & dl3s[2] };

            p1 += countBits(du1) + countBits(du2);
        }
    }

    var p2: u32 = 0;

    if (height >= 3) {
        for (1..height - 1) |y| {
            const r_prev = rows.items[y - 1];

            const r_mid = rows.items[y];

            const r_next = rows.items[y + 1];

            const nw_m = shiftLeft(r_prev.m, 1, mask_last);

            const nw_s = shiftLeft(r_prev.s, 1, mask_last);

            const se_m = shiftRight(r_next.m, 1, mask_last);

            const se_s = shiftRight(r_next.s, 1, mask_last);

            const diag1 = .{ (nw_m[0] & se_s[0]) | (nw_s[0] & se_m[0]), (nw_m[1] & se_s[1]) | (nw_s[1] & se_m[1]), (nw_m[2] & se_s[2]) | (nw_s[2] & se_m[2]) | 0 };

            const ne_m = shiftRight(r_prev.m, 1, mask_last);

            const ne_s = shiftRight(r_prev.s, 1, mask_last);

            const sw_m = shiftLeft(r_next.m, 1, mask_last);

            const sw_s = shiftLeft(r_next.s, 1, mask_last);

            const diag2 = .{ (ne_m[0] & sw_s[0]) | (ne_s[0] & sw_m[0]), (ne_m[1] & sw_s[1]) | (ne_s[1] & sw_m[1]), (ne_m[2] & sw_s[2]) | (ne_s[2] & sw_m[2]) | 0 };

            const both = .{ r_mid.a[0] & diag1[0] & diag2[0], r_mid.a[1] & diag1[1] & diag2[1], r_mid.a[2] & diag1[2] & diag2[2] };

            p2 += countBits(both);
        }
    }

    return Result{ .p1 = p1, .p2 = p2 };
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
