const std = @import("std");
const Result = struct { p1: u32, p2: []const u8 };
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const result = solve(input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {s}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn solve(input: []const u8) Result {
    @setRuntimeSafety(false);
    var screen = [_]u64{0} ** 6;
    var i: usize = 0;
    while (i < input.len) {
        const line_start = i;
        while (i < input.len and input[i] != '\n' and input[i] != '\r') : (i += 1) {}
        const line = input[line_start..i];
        while (i < input.len and (input[i] == '\n' or input[i] == '\r')) : (i += 1) {}
        if (line.len == 0) continue;
        if (std.mem.startsWith(u8, line, "rect ")) {
            var j: usize = 5;
            var w: u32 = 0;
            while (j < line.len and line[j] >= '0' and line[j] <= '9') : (j += 1) {
                w = w * 10 + (line[j] - '0');
            }
            j += 1;
            var h: u32 = 0;
            while (j < line.len and line[j] >= '0' and line[j] <= '9') : (j += 1) {
                h = h * 10 + (line[j] - '0');
            }
            const mask = (@as(u64, 1) << @intCast(w)) - 1;
            for (0..h) |y| {
                screen[y] |= mask;
            }
        } else if (std.mem.startsWith(u8, line, "rotate row y=")) {
            var j: usize = 13;
            var y: u32 = 0;
            while (j < line.len and line[j] >= '0' and line[j] <= '9') : (j += 1) {
                y = y * 10 + (line[j] - '0');
            }
            while (j < line.len and (line[j] < '0' or line[j] > '9')) : (j += 1) {}
            var amt_raw: u32 = 0;
            while (j < line.len and line[j] >= '0' and line[j] <= '9') : (j += 1) {
                amt_raw = amt_raw * 10 + (line[j] - '0');
            }
            const amt: u6 = @intCast(amt_raw % 50);
            const row = screen[y];
            screen[y] = ((row << amt) | (row >> (50 - amt))) & ((@as(u64, 1) << 50) - 1);
        } else if (std.mem.startsWith(u8, line, "rotate column x=")) {
            var j: usize = 16;
            var x: u6 = 0;
            while (j < line.len and line[j] >= '0' and line[j] <= '9') : (j += 1) {
                x = @intCast((x * 10 + (line[j] - '0')) % 64);
            }
            while (j < line.len and (line[j] < '0' or line[j] > '9')) : (j += 1) {}
            var amt_raw: u32 = 0;
            while (j < line.len and line[j] >= '0' and line[j] <= '9') : (j += 1) {
                amt_raw = amt_raw * 10 + (line[j] - '0');
            }
            const amt = amt_raw % 6;
            const mask = @as(u64, 1) << x;
            var col: u8 = 0;
            for (screen, 0..) |row, ii| {
                if (row & mask != 0) {
                    col |= @as(u8, 1) << @intCast(ii);
                }
            }
            col = ((col << @intCast(amt)) | (col >> @intCast(6 - amt))) & 0x3F;
            for (&screen, 0..) |*row, ii| {
                if (col & (@as(u8, 1) << @intCast(ii)) != 0) {
                    row.* |= mask;
                } else {
                    row.* &= ~mask;
                }
            }
        }
    }
    var p1: u32 = 0;
    for (screen) |row| {
        p1 += @popCount(row);
    }
    std.debug.print("\nPart 2 display:\n", .{});
    for (screen) |row| {
        for (0..50) |x| {
            const c: u8 = if (row & (@as(u64, 1) << @intCast(x)) != 0) '#' else ' ';
            std.debug.print("{c}", .{c});
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});
    return .{ .p1 = p1, .p2 = "See display above" };
}
