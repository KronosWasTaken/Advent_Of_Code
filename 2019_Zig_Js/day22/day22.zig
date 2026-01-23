const std = @import("std");

const Result = struct { p1: i128, p2: i128 };

const Technique = struct {
    a: i128,
    c: i128,
    m: i128,

    fn compose(self: Technique, other: Technique) Technique {
        const m = self.m;
        const a = @mod(self.a * other.a, m);
        const c = @mod(self.c * other.a + other.c, m);
        return .{ .a = a, .c = c, .m = m };
    }

    fn modPow(base: i128, exp: i128, mod: i128) i128 {
        var result: i128 = 1;
        var b = @mod(base, mod);
        var e = exp;

        if (e < 0) e = mod - 1 + e;

        while (e > 0) {
            if (e & 1 == 1) {
                result = @mod(result * b, mod);
            }
            b = @mod(b * b, mod);
            e >>= 1;
        }
        return result;
    }

    fn modInv(a: i128, m: i128) i128 {

        var t: i128 = 0;
        var newt: i128 = 1;
        var r = m;
        var newr = a;

        while (newr != 0) {
            const quotient = @divFloor(r, newr);
            const temp_t = t;
            t = newt;
            newt = temp_t - quotient * newt;

            const temp_r = r;
            r = newr;
            newr = temp_r - quotient * newr;
        }

        if (t < 0) t += m;
        return t;
    }

    fn inverse(self: Technique) Technique {
        const m = self.m;
        const a = modInv(self.a, m);
        const c = @mod(m - @mod(a * self.c, m), m);
        return .{ .a = a, .c = c, .m = m };
    }

    fn power(self: Technique, exp: i128) Technique {
        const m = self.m;
        const a = modPow(self.a, exp, m);

        const numerator = @mod(@mod(a - 1, m) * self.c, m);
        const denominator = modInv(self.a - 1, m);
        const c = @mod(numerator * denominator, m);
        return .{ .a = a, .c = c, .m = m };
    }

    fn shuffle(self: Technique, index: i128) i128 {
        return @mod(self.a * index + self.c, self.m);
    }
};

fn solve(input: []const u8) Result {
    var t1 = Technique{ .a = 1, .c = 0, .m = 10007 };
    var t2 = Technique{ .a = 1, .c = 0, .m = 119315717514047 };

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        if (std.mem.indexOf(u8, line, "deal into new stack")) |_| {

            t1 = t1.compose(.{ .a = t1.m - 1, .c = t1.m - 1, .m = t1.m });
            t2 = t2.compose(.{ .a = t2.m - 1, .c = t2.m - 1, .m = t2.m });
        } else if (std.mem.indexOf(u8, line, "deal with increment")) |_| {
            var n: i128 = 0;
            for (line) |c| {
                if (c >= '0' and c <= '9') {
                    n = n * 10 + (c - '0');
                }
            }

            t1 = t1.compose(.{ .a = n, .c = 0, .m = t1.m });
            t2 = t2.compose(.{ .a = n, .c = 0, .m = t2.m });
        } else if (std.mem.indexOf(u8, line, "cut")) |_| {
            var n: i128 = 0;
            var neg = false;
            for (line) |c| {
                if (c == '-') neg = true
                else if (c >= '0' and c <= '9') n = n * 10 + (c - '0');
            }
            if (neg) n = -n;

            const c = @mod(t1.m - @mod(n, t1.m), t1.m);
            t1 = t1.compose(.{ .a = 1, .c = c, .m = t1.m });

            const c2 = @mod(t2.m - @mod(n, t2.m), t2.m);
            t2 = t2.compose(.{ .a = 1, .c = c2, .m = t2.m });
        }
    }

    const part1 = t1.shuffle(2019);


    const t2_inv = t2.inverse();
    const t2_final = t2_inv.power(101741582076661);
    const part2 = t2_final.shuffle(2020);

    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");

    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\nPart 2: {}\nTime: {d:.2} microseconds\n", .{result.p1, result.p2, elapsed_us});
}
