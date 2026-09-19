const std = @import("std");

fn runIntcode(code: []const i64, x: i64, y: i64) bool {
    var mem: [1024]i64 = undefined;
    @memcpy(mem[0..code.len], code);
    @memset(mem[code.len..], 0);

    var ip: usize = 0;
    var rel_base: i64 = 0;
    var input_step: usize = 0;

    while (true) {
        const instr = mem[ip];
        const opcode = @mod(instr, 100);
        const m1 = @mod(@divFloor(instr, 100), 10);
        const m2 = @mod(@divFloor(instr, 1000), 10);
        const m3 = @mod(@divFloor(instr, 10000), 10);

        const getParam = struct {
            fn get(m: []const i64, rb: i64, mode: i64, val: i64) i64 {
                return switch (mode) {
                    0 => m[@intCast(val)],
                    1 => val,
                    2 => m[@intCast(rb + val)],
                    else => 0,
                };
            }
        }.get;

        const getAddr = struct {
            fn addr(rb: i64, mode: i64, val: i64) usize {
                return switch (mode) {
                    0 => @intCast(val),
                    2 => @intCast(rb + val),
                    else => @intCast(val),
                };
            }
        }.addr;

        switch (opcode) {
            1 => {
                const a = getParam(&mem, rel_base, m1, mem[ip + 1]);
                const b = getParam(&mem, rel_base, m2, mem[ip + 2]);
                const dst = getAddr(rel_base, m3, mem[ip + 3]);
                mem[dst] = a + b;
                ip += 4;
            },
            2 => {
                const a = getParam(&mem, rel_base, m1, mem[ip + 1]);
                const b = getParam(&mem, rel_base, m2, mem[ip + 2]);
                const dst = getAddr(rel_base, m3, mem[ip + 3]);
                mem[dst] = a * b;
                ip += 4;
            },
            3 => {
                const dst = getAddr(rel_base, m1, mem[ip + 1]);
                if (input_step == 0) {
                    mem[dst] = x;
                    input_step = 1;
                } else {
                    mem[dst] = y;
                    input_step = 2;
                }
                ip += 2;
            },
            4 => {
                const val = getParam(&mem, rel_base, m1, mem[ip + 1]);
                return val == 1;
            },
            5 => {
                const cond = getParam(&mem, rel_base, m1, mem[ip + 1]);
                const target = getParam(&mem, rel_base, m2, mem[ip + 2]);
                if (cond != 0) {
                    ip = @intCast(target);
                } else {
                    ip += 3;
                }
            },
            6 => {
                const cond = getParam(&mem, rel_base, m1, mem[ip + 1]);
                const target = getParam(&mem, rel_base, m2, mem[ip + 2]);
                if (cond == 0) {
                    ip = @intCast(target);
                } else {
                    ip += 3;
                }
            },
            7 => {
                const a = getParam(&mem, rel_base, m1, mem[ip + 1]);
                const b = getParam(&mem, rel_base, m2, mem[ip + 2]);
                const dst = getAddr(rel_base, m3, mem[ip + 3]);
                mem[dst] = if (a < b) 1 else 0;
                ip += 4;
            },
            8 => {
                const a = getParam(&mem, rel_base, m1, mem[ip + 1]);
                const b = getParam(&mem, rel_base, m2, mem[ip + 2]);
                const dst = getAddr(rel_base, m3, mem[ip + 3]);
                mem[dst] = if (a == b) 1 else 0;
                ip += 4;
            },
            9 => {
                const a = getParam(&mem, rel_base, m1, mem[ip + 1]);
                rel_base += a;
                ip += 2;
            },
            99 => return false,
            else => return false,
        }
    }
}

const BeamGeometry = struct {
    code: []const i64,
    scale: i64,
    lower: i64,
    upper: i64,

    fn isInside(self: BeamGeometry, x: i64, y: i64) bool {
        if (self.scale * y <= self.upper * x) {
            return false;
        }
        if (self.scale * x <= self.lower * y) {
            return false;
        }
        return runIntcode(self.code, x, y);
    }
};

fn parseBeamGeometry(code: []const i64) BeamGeometry {
    var lower: i64 = 1;
    var upper: i64 = 1;
    var scale: i64 = 5;

    while (scale < 1024) {
        scale *= 2;
        lower *= 2;
        upper *= 2;

        while (!runIntcode(code, lower + 1, scale)) {
            lower += 1;
        }
        while (!runIntcode(code, scale, upper + 1)) {
            upper += 1;
        }
    }

    return .{
        .code = code,
        .scale = scale,
        .lower = lower,
        .upper = upper,
    };
}

fn solveTractor(code: []const i64) struct { p1: i64, p2: i64 } {
    const geo = parseBeamGeometry(code);

    var part1: i64 = 1;
    var y: i64 = 1;
    while (y < 50) : (y += 1) {
        var left: ?i64 = null;
        var right: ?i64 = null;

        var x: i64 = 1;
        while (x < 50) : (x += 1) {
            if (geo.isInside(x, y)) {
                left = x;
                break;
            }
        }

        if (left) |l| {
            var rx: i64 = 49;
            while (rx >= l) : (rx -= 1) {
                if (geo.isInside(rx, y)) {
                    right = rx;
                    break;
                }
            }
            if (right) |r| {
                part1 += r - l + 1;
            }
        }
    }

    const det = geo.scale * geo.scale - geo.lower * geo.upper;
    var px = @divTrunc(99 * (geo.lower * geo.upper + geo.lower * geo.scale), det);
    var py = @divTrunc(99 * (geo.lower * geo.upper + geo.upper * geo.scale), det);
    var moved = true;

    while (moved) {
        moved = false;
        while (!geo.isInside(px, py + 99)) {
            px += 1;
            moved = true;
        }
        while (!geo.isInside(px + 99, py)) {
            py += 1;
            moved = true;
        }
    }

    const part2 = 10000 * px + py;
    return .{
        .p1 = part1,
        .p2 = part2,
    };
}

fn parseProgram(input: []const u8, buf: []i64) []const i64 {
    var len: usize = 0;
    var it = std.mem.tokenizeAny(u8, input, ",\r\n ");
    while (it.next()) |token| {
        if (token.len == 0) {
            continue;
        }
        buf[len] = std.fmt.parseInt(i64, token, 10) catch continue;
        len += 1;
    }
    return buf[0..len];
}

pub fn main() !void {
    const raw = @embedFile("input.txt");
    var code_buf: [1024]i64 = undefined;
    const code = parseProgram(raw, &code_buf);

    var timer = try std.time.Timer.start();
    const res = solveTractor(code);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;

    std.debug.print("Part 1: {}\nPart 2: {}\n", .{ res.p1, res.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
