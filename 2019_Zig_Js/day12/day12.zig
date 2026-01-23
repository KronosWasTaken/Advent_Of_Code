const std = @import("std");

const Result = struct {
    p1: i64,
    p2: i64,
};


inline fn signum(a: i64, b: i64) i64 {
    return @as(i64, @bitCast(@as(u64, @bitCast(a -% b)) >> 63)) | (@as(i64, @bitCast(@as(u64, @bitCast(b -% a)) >> 63)));
}


inline fn gcd(a: i64, b: i64) i64 {
    var x = if (a < 0) -a else a;
    var y = if (b < 0) -b else b;
    if (x == 0) return y;
    if (y == 0) return x;


    var shift: u6 = 0;
    while ((x | y) & 1 == 0) : (shift += 1) {
        x >>= 1;
        y >>= 1;
    }
    while (x & 1 == 0) x >>= 1;

    while (y != 0) {
        while (y & 1 == 0) y >>= 1;
        if (x > y) {
            const temp = x;
            x = y;
            y = temp;
        }
        y -= x;
    }
    return x << shift;
}

inline fn lcm(a: i64, b: i64) i64 {
    return @divExact(a, gcd(a, b)) * b;
}


inline fn step32(axis: [8]i32) [8]i32 {

    const p0: i64 = axis[0];
    const p1: i64 = axis[1];
    const p2: i64 = axis[2];
    const p3: i64 = axis[3];
    const v0: i64 = axis[4];
    const v1: i64 = axis[5];
    const v2: i64 = axis[6];
    const v3: i64 = axis[7];


    const a: i64 = if (p1 > p0) 1 else if (p1 < p0) -1 else 0;
    const b: i64 = if (p2 > p0) 1 else if (p2 < p0) -1 else 0;
    const c: i64 = if (p3 > p0) 1 else if (p3 < p0) -1 else 0;
    const d: i64 = if (p2 > p1) 1 else if (p2 < p1) -1 else 0;
    const e: i64 = if (p3 > p1) 1 else if (p3 < p1) -1 else 0;
    const f: i64 = if (p3 > p2) 1 else if (p3 < p2) -1 else 0;


    const n0: i64 = v0 + a + b + c;
    const n1: i64 = v1 - a + d + e;
    const n2: i64 = v2 - b - d + f;
    const n3: i64 = v3 - c - e - f;


    return [8]i32{
        @as(i32, @intCast(p0 + n0)),
        @as(i32, @intCast(p1 + n1)),
        @as(i32, @intCast(p2 + n2)),
        @as(i32, @intCast(p3 + n3)),
        @as(i32, @intCast(n0)),
        @as(i32, @intCast(n1)),
        @as(i32, @intCast(n2)),
        @as(i32, @intCast(n3)),
    };
}


inline fn step64(axis: [8]i64) [8]i64 {
    const p0 = axis[0];
    const p1 = axis[1];
    const p2 = axis[2];
    const p3 = axis[3];
    const v0 = axis[4];
    const v1 = axis[5];
    const v2 = axis[6];
    const v3 = axis[7];


    const a = if (p1 > p0) @as(i64, 1) else if (p1 < p0) @as(i64, -1) else @as(i64, 0);
    const b = if (p2 > p0) @as(i64, 1) else if (p2 < p0) @as(i64, -1) else @as(i64, 0);
    const c = if (p3 > p0) @as(i64, 1) else if (p3 < p0) @as(i64, -1) else @as(i64, 0);
    const d = if (p2 > p1) @as(i64, 1) else if (p2 < p1) @as(i64, -1) else @as(i64, 0);
    const e = if (p3 > p1) @as(i64, 1) else if (p3 < p1) @as(i64, -1) else @as(i64, 0);
    const f = if (p3 > p2) @as(i64, 1) else if (p3 < p2) @as(i64, -1) else @as(i64, 0);


    const n0 = v0 + a + b + c;
    const n1 = v1 - a + d + e;
    const n2 = v2 - b - d + f;
    const n3 = v3 - c - e - f;


    return [8]i64{
        p0 + n0, p1 + n1, p2 + n2, p3 + n3,
        n0, n1, n2, n3,
    };
}

inline fn stopped32(axis: [8]i32) bool {
    return (axis[4] | axis[5] | axis[6] | axis[7]) == 0;
}

inline fn stopped64(axis: [8]i64) bool {
    return (axis[4] | axis[5] | axis[6] | axis[7]) == 0;
}

fn findCycleAxis(init_pos: [4]i32, init_vel: [4]i32) i64 {
    var axis: [8]i64 = undefined;
    axis[0] = init_pos[0];
    axis[1] = init_pos[1];
    axis[2] = init_pos[2];
    axis[3] = init_pos[3];
    axis[4] = init_vel[0];
    axis[5] = init_vel[1];
    axis[6] = init_vel[2];
    axis[7] = init_vel[3];

    var count: i64 = 0;

    while (true) {
        axis = step64(axis);
        count += 1;
        if (stopped64(axis)) {
            break;
        }
    }

    return count * 2;
}

fn solve(input: []const u8) Result {

    var positions: [3][4]i32 = undefined;


    var moon: usize = 0;
    var axis_idx: usize = 0;
    var num: i32 = 0;
    var negative = false;

    for (input) |c| {
        if (c == '-') {
            negative = true;
        } else if (c >= '0' and c <= '9') {
            num = num * 10 + @as(i32, c - '0');
        } else if (c == 'x' or c == 'y' or c == 'z') {
            axis_idx = if (c == 'x') 0 else if (c == 'y') 1 else 2;
        } else if (c == ',' and (num != 0 or negative)) {

            positions[axis_idx][moon] = if (negative) -num else num;
            negative = false;
            num = 0;
        } else if (c == '>' and (num != 0 or negative)) {

            positions[axis_idx][moon] = if (negative) -num else num;
            negative = false;
            num = 0;
            if (moon < 3) {
                moon += 1;
            }
        }
    }


    var pos_x: [8]i32 = .{
        positions[0][0], positions[0][1], positions[0][2], positions[0][3],
        0, 0, 0, 0,
    };
    var pos_y: [8]i32 = .{
        positions[1][0], positions[1][1], positions[1][2], positions[1][3],
        0, 0, 0, 0,
    };
    var pos_z: [8]i32 = .{
        positions[2][0], positions[2][1], positions[2][2], positions[2][3],
        0, 0, 0, 0,
    };


    for (0..1000) |_| {
        pos_x = step32(pos_x);
        pos_y = step32(pos_y);
        pos_z = step32(pos_z);
    }


    var part1: i64 = 0;
    inline for (0..4) |i| {
        const px: i64 = pos_x[i];
        const py: i64 = pos_y[i];
        const pz: i64 = pos_z[i];
        const vx: i64 = pos_x[i + 4];
        const vy: i64 = pos_y[i + 4];
        const vz: i64 = pos_z[i + 4];

        const abs_pot_x = if (px < 0) -px else px;
        const abs_pot_y = if (py < 0) -py else py;
        const abs_pot_z = if (pz < 0) -pz else pz;
        const abs_kin_x = if (vx < 0) -vx else vx;
        const abs_kin_y = if (vy < 0) -vy else vy;
        const abs_kin_z = if (vz < 0) -vz else vz;

        const total_pot = abs_pot_x + abs_pot_y + abs_pot_z;
        const total_kin = abs_kin_x + abs_kin_y + abs_kin_z;
        part1 += total_pot * total_kin;
    }


    const cycle_x_pos: [4]i32 = .{ positions[0][0], positions[0][1], positions[0][2], positions[0][3] };
    const cycle_y_pos: [4]i32 = .{ positions[1][0], positions[1][1], positions[1][2], positions[1][3] };
    const cycle_z_pos: [4]i32 = .{ positions[2][0], positions[2][1], positions[2][2], positions[2][3] };
    const cycle_vel: [4]i32 = .{ 0, 0, 0, 0 };

    const cycle_x = findCycleAxis(cycle_x_pos, cycle_vel);
    const cycle_y = findCycleAxis(cycle_y_pos, cycle_vel);
    const cycle_z = findCycleAxis(cycle_z_pos, cycle_vel);

    var part2 = lcm(cycle_x, cycle_y);
    part2 = lcm(part2, cycle_z);

    return Result{ .p1 = part1, .p2 = part2 };
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
