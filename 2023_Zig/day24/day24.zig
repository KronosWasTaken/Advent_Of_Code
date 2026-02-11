const std = @import("std");

const Result = struct { p1: u32, p2: i128 };

const Vector = struct { x: i128, y: i128, z: i128 };

fn add(a: Vector, b: Vector) Vector {
    return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
}

fn sub(a: Vector, b: Vector) Vector {
    return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
}

fn cross(a: Vector, b: Vector) Vector {
    return .{ .x = a.y * b.z - a.z * b.y, .y = a.z * b.x - a.x * b.z, .z = a.x * b.y - a.y * b.x };
}

fn gcd(a: i128, b: i128) i128 {
    var x = if (a < 0) -a else a;
    var y = if (b < 0) -b else b;
    while (y != 0) {
        const t = @rem(x, y);
        x = y;
        y = t;
    }
    return x;
}

fn vecGcd(v: Vector) Vector {
    const g = gcd(gcd(v.x, v.y), v.z);
    return .{ .x = @divTrunc(v.x, g), .y = @divTrunc(v.y, g), .z = @divTrunc(v.z, g) };
}

fn sum(v: Vector) i128 {
    return v.x + v.y + v.z;
}

const RANGE_MIN: i64 = 200_000_000_000_000;
const RANGE_MAX: i64 = 400_000_000_000_000;

pub fn solve(input: []const u8) Result {
    var numbers = std.ArrayListUnmanaged([6]i64){};
    defer numbers.deinit(std.heap.page_allocator);
    var it = std.mem.tokenizeAny(u8, input, "\r\n,@ ");
    var buf: [6]i64 = undefined;
    var idx: usize = 0;
    while (it.next()) |tok| {
        var value: i64 = 0;
        var sign: i64 = 1;
        var j: usize = 0;
        if (tok[0] == '-') {
            sign = -1;
            j = 1;
        }
        while (j < tok.len) : (j += 1) value = value * 10 + @as(i64, tok[j] - '0');
        buf[idx] = value * sign;
        idx += 1;
        if (idx == 6) {
            idx = 0;
            numbers.append(std.heap.page_allocator, buf) catch return .{ .p1 = 0, .p2 = 0 };
        }
    }

    var p1: u32 = 0;
    var i: usize = 1;
    while (i < numbers.items.len) : (i += 1) {
        const a = numbers.items[i];
        var j: usize = 0;
        while (j < i) : (j += 1) {
            const b = numbers.items[j];
            const determinant = a[4] * b[3] - a[3] * b[4];
            if (determinant == 0) continue;

            const t = @divTrunc(b[3] * (b[1] - a[1]) - b[4] * (b[0] - a[0]), determinant);
            const u = @divTrunc(a[3] * (b[1] - a[1]) - a[4] * (b[0] - a[0]), determinant);
            const x = a[0] + t * a[3];
            const y = a[1] + t * a[4];
            if (t >= 0 and u >= 0 and x >= RANGE_MIN and x <= RANGE_MAX and y >= RANGE_MIN and y <= RANGE_MAX) {
                p1 += 1;
            }
        }
    }

    const widen = struct {
        fn get(vals: [6]i64) struct { p: Vector, v: Vector } {
            return .{
                .p = .{ .x = vals[0], .y = vals[1], .z = vals[2] },
                .v = .{ .x = vals[3], .y = vals[4], .z = vals[5] },
            };
        }
    }.get;

    const s0 = widen(numbers.items[0]);
    const s1 = widen(numbers.items[1]);
    const s2 = widen(numbers.items[2]);

    const p3 = sub(s1.p, s0.p);
    const p4 = sub(s2.p, s0.p);
    const v3 = sub(s1.v, s0.v);
    const v4 = sub(s2.v, s0.v);

    const q = vecGcd(cross(v3, p3));
    const r = vecGcd(cross(v4, p4));
    const s = vecGcd(cross(q, r));

    const t = @divTrunc(p3.y * s.x - p3.x * s.y, v3.x * s.y - v3.y * s.x);
    const u = @divTrunc(p4.y * s.x - p4.x * s.y, v4.x * s.y - v4.y * s.x);

    const a = sum(add(s0.p, p3));
    const b = sum(add(s0.p, p4));
    const c = sum(sub(v3, v4));
    const p2 = @divTrunc(u * a - t * b + u * t * c, u - t);

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
