const std = @import("std");

const Result = struct {
    p1: i64,
    p2: []const u8,
};

const Pos = struct { irow: i32, icol: i32 };

const Dir = struct { drow: i32, dcol: i32 };

fn turnDir(dir: Dir, turn: i64) Dir {
    if (turn == 0) {
        return Dir{ .drow = -dir.dcol, .dcol = dir.drow };
    } else {
        return Dir{ .drow = dir.dcol, .dcol = -dir.drow };
    }
}

const Computer = struct {
    code: []i64,
    pc: usize = 0,
    rb: i64 = 0,
    input_val: i64 = 0,
    halted: bool = false,

    fn getParam(self: *Computer, mode: i64, param: i64) i64 {
        return switch (mode) {
            0 => self.code[@as(usize, @intCast(param))],
            1 => param,
            2 => self.code[@as(usize, @intCast(self.rb + param))],
            else => unreachable,
        };
    }

    fn setParam(self: *Computer, mode: i64, param: i64, value: i64) void {
        const addr: usize = switch (mode) {
            0 => @as(usize, @intCast(param)),
            1 => unreachable,
            2 => @as(usize, @intCast(self.rb + param)),
            else => unreachable,
        };
        self.code[addr] = value;
    }

    fn run(self: *Computer) ?i64 {
        if (self.halted) return null;

        while (true) {
            const instr = self.code[self.pc];
            const opcode = @mod(instr, 100);
            const mode1 = @mod(@divFloor(instr, 100), 10);
            const mode2 = @mod(@divFloor(instr, 1000), 10);
            const mode3 = @mod(@divFloor(instr, 10000), 10);

            const p1 = if (self.pc + 1 < self.code.len) self.code[self.pc + 1] else 0;
            const p2 = if (self.pc + 2 < self.code.len) self.code[self.pc + 2] else 0;
            const p3 = if (self.pc + 3 < self.code.len) self.code[self.pc + 3] else 0;

            switch (opcode) {
                1 => {
                    const a = self.getParam(mode1, p1);
                    const b = self.getParam(mode2, p2);
                    self.setParam(mode3, p3, a + b);
                    self.pc += 4;
                },
                2 => {
                    const a = self.getParam(mode1, p1);
                    const b = self.getParam(mode2, p2);
                    self.setParam(mode3, p3, a * b);
                    self.pc += 4;
                },
                3 => {
                    self.setParam(mode1, p1, self.input_val);
                    self.pc += 2;
                },
                4 => {
                    const val = self.getParam(mode1, p1);
                    self.pc += 2;
                    return val;
                },
                5 => {
                    const a = self.getParam(mode1, p1);
                    if (a != 0) {
                        self.pc = @as(usize, @intCast(self.getParam(mode2, p2)));
                    } else {
                        self.pc += 3;
                    }
                },
                6 => {
                    const a = self.getParam(mode1, p1);
                    if (a == 0) {
                        self.pc = @as(usize, @intCast(self.getParam(mode2, p2)));
                    } else {
                        self.pc += 3;
                    }
                },
                7 => {
                    const a = self.getParam(mode1, p1);
                    const b = self.getParam(mode2, p2);
                    self.setParam(mode3, p3, if (a < b) 1 else 0);
                    self.pc += 4;
                },
                8 => {
                    const a = self.getParam(mode1, p1);
                    const b = self.getParam(mode2, p2);
                    self.setParam(mode3, p3, if (a == b) 1 else 0);
                    self.pc += 4;
                },
                9 => {
                    const a = self.getParam(mode1, p1);
                    self.rb += a;
                    self.pc += 2;
                },
                99 => {
                    self.halted = true;
                    return null;
                },
                else => unreachable,
            }
        }
    }
};

fn run(input: []const u8, allocator: std.mem.Allocator, start_color: i64) !std.AutoHashMap(Pos, i64) {
    var code: [20000]i64 = undefined;
    @memset(&code, 0);
    var code_len: usize = 0;

    var num: i64 = 0;
    var negative = false;
    var in_number = false;

    for (input) |c| {
        if (c == '-') {
            negative = true;
            in_number = true;
        } else if (c >= '0' and c <= '9') {
            num = num * 10 + (c - '0');
            in_number = true;
        } else if (c == ',' or c == '\n' or c == '\r') {
            if (in_number) {
                code[code_len] = if (negative) -num else num;
                code_len += 1;
                num = 0;
                negative = false;
                in_number = false;
            }
        }
    }
    if (in_number) {
        code[code_len] = if (negative) -num else num;
        code_len += 1;
    }

    var mtx = std.AutoHashMap(Pos, i64).init(allocator);
    var pos = Pos{ .irow = 0, .icol = 0 };
    var dir = Dir{ .drow = -1, .dcol = 0 };

    try mtx.put(pos, start_color);

    var computer = Computer{ .code = &code };

    while (true) {
        const current_color = mtx.get(pos) orelse 0;
        computer.input_val = current_color;

        if (computer.run()) |paint_color| {
            try mtx.put(pos, paint_color);

            if (computer.run()) |turn| {
                dir = turnDir(dir, turn);
                pos.irow += dir.drow;
                pos.icol += dir.dcol;
            } else {
                break;
            }
        } else {
            break;
        }
    }

    return mtx;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var mtx1 = try run(input, allocator, 0);
    defer mtx1.deinit();
    const part1: i64 = @as(i64, @intCast(mtx1.count()));

    var mtx2 = try run(input, allocator, 1);
    defer mtx2.deinit();

    var min_row: i32 = std.math.maxInt(i32);
    var max_row: i32 = std.math.minInt(i32);
    var min_col: i32 = std.math.maxInt(i32);
    var max_col: i32 = std.math.minInt(i32);

    var iter = mtx2.keyIterator();
    while (iter.next()) |pos_ptr| {
        const p = pos_ptr.*;
        if (mtx2.get(p) == 1) {
            min_row = @min(min_row, p.irow);
            max_row = @max(max_row, p.irow);
            min_col = @min(min_col, p.icol);
            max_col = @max(max_col, p.icol);
        }
    }

    var output = try std.ArrayList(u8).initCapacity(allocator, 1000);
    defer output.deinit(allocator);

    if (min_row <= max_row and min_col <= max_col) {
        var row = min_row;
        while (row <= max_row) : (row += 1) {
            var col = min_col;
            while (col <= max_col) : (col += 1) {
                const p = Pos{ .irow = row, .icol = col };
                const color = mtx2.get(p) orelse 0;
                if (color == 1) {
                    try output.append(allocator, '#');
                } else {
                    try output.append(allocator, ' ');
                }
            }
            try output.append(allocator, '\n');
        }
    } else {
        try output.appendSlice(allocator, "(empty)\n");
    }

    const part2 = try output.toOwnedSlice(allocator);

    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, allocator);
    defer allocator.free(result.p2);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2:\n{s}", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
