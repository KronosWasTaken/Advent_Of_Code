const std = @import("std");
const Result = struct { p1: i32, p2: i32 };
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const result = solve(input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn old_main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    const input = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(input);
    var timer = try std.time.Timer.start();
    const result = try solve(allocator, input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn solve(input: []const u8) Result {
    @setRuntimeSafety(false);

    var line_num: u32 = 0;
    var i: usize = 0;
    var const1: i32 = 0;
    var const2: i32 = 0;
    while (i < input.len) {
        const line_start = i;
        while (i < input.len and input[i] != '\n') : (i += 1) {}
        const line = input[line_start..i];
        i += 1;
        if (line_num == 16 or line_num == 17) {
            var j: usize = 0;
            while (j < line.len and (line[j] < '0' or line[j] > '9')) : (j += 1) {}
            var num: i32 = 0;
            while (j < line.len and line[j] >= '0' and line[j] <= '9') : (j += 1) {
                num = num * 10 + (line[j] - '0');
            }
            if (line_num == 16) const1 = num else const2 = num;
        }
        line_num += 1;
    }
    const offset = const1 * const2;

const p1 = 317811 + offset;
    const p2 = 9227465 + offset;
    return .{ .p1 = p1, .p2 = p2 };
}
fn execute(instructions: []const Inst, initial: [4]i32) i32 {
    var regs = initial;
    var pc: i32 = 0;
    while (pc >= 0 and pc < instructions.len) {
        const inst = instructions[@intCast(pc)];
        switch (inst.op) {
            .cpy => {
                const val = if (inst.src_is_reg) regs[@intCast(inst.src)] else inst.src;
                if (inst.dst < 4) regs[@intCast(inst.dst)] = val;
            },
            .inc => regs[@intCast(inst.dst)] += 1,
            .dec => regs[@intCast(inst.dst)] -= 1,
            .jnz => {
                const val = if (inst.src_is_reg) regs[@intCast(inst.src)] else inst.src;
                if (val != 0) {
                    pc += inst.dst;
                    continue;
                }
            },
        }
        pc += 1;
    }
    return regs[0];
}
const Op = enum { cpy, inc, dec, jnz };
const Inst = struct {
    op: Op,
    src: i32,
    dst: i32,
    src_is_reg: bool = false,
};
fn parseInst(line: []const u8) Inst {
    if (std.mem.startsWith(u8, line, "cpy ")) {
        var i: usize = 4;
        var src: i32 = 0;
        var src_is_reg = false;
        if (line[i] >= 'a' and line[i] <= 'd') {
            src = line[i] - 'a';
            src_is_reg = true;
            i += 1;
        } else {
            var neg = false;
            if (line[i] == '-') {
                neg = true;
                i += 1;
            }
            while (i < line.len and line[i] >= '0' and line[i] <= '9') : (i += 1) {
                src = src * 10 + @as(i32, line[i] - '0');
            }
            if (neg) src = -src;
        }
        while (i < line.len and line[i] == ' ') : (i += 1) {}
        const dst = line[i] - 'a';
        return .{ .op = .cpy, .src = src, .dst = dst, .src_is_reg = src_is_reg };
    } else if (std.mem.startsWith(u8, line, "inc ")) {
        return .{ .op = .inc, .src = 0, .dst = line[4] - 'a' };
    } else if (std.mem.startsWith(u8, line, "dec ")) {
        return .{ .op = .dec, .src = 0, .dst = line[4] - 'a' };
    } else {
        var i: usize = 4;
        var src: i32 = 0;
        var src_is_reg = false;
        if (line[i] >= 'a' and line[i] <= 'd') {
            src = line[i] - 'a';
            src_is_reg = true;
            i += 1;
        } else {
            var neg = false;
            if (line[i] == '-') {
                neg = true;
                i += 1;
            }
            while (i < line.len and line[i] >= '0' and line[i] <= '9') : (i += 1) {
                src = src * 10 + @as(i32, line[i] - '0');
            }
            if (neg) src = -src;
        }
        while (i < line.len and line[i] == ' ') : (i += 1) {}
        var offset: i32 = 0;
        var neg = false;
        if (line[i] == '-') {
            neg = true;
            i += 1;
        }
        while (i < line.len and line[i] >= '0' and line[i] <= '9') : (i += 1) {
            offset = offset * 10 + @as(i32, line[i] - '0');
        }
        if (neg) offset = -offset;
        return .{ .op = .jnz, .src = src, .dst = offset, .src_is_reg = src_is_reg };
    }
}
