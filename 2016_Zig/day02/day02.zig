const std = @import("std");
const Result = struct { p1: [8]u8, p2: [8]u8, p1_len: usize, p2_len: usize };
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {s} | Part 2: {s}\n", .{ result.p1[0..result.p1_len], result.p2[0..result.p2_len] });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn solve(input: []const u8) Result {
    @setRuntimeSafety(false);
    var code1: [8]u8 = undefined;
    var code2: [8]u8 = undefined;
    var len1: usize = 0;
    var len2: usize = 0;

    var x1: i8 = 1;
    var y1: i8 = 1;

    var x2: i8 = -2;
    var y2: i8 = 0;
    var i: usize = 0;
    while (i < input.len) {

        while (i < input.len) {
            const c = input[i];
            i += 1;
            if (c == '\n' or c == '\r') break;

            switch (c) {
                'U' => y1 = @max(0, y1 - 1),
                'D' => y1 = @min(2, y1 + 1),
                'L' => x1 = @max(0, x1 - 1),
                'R' => x1 = @min(2, x1 + 1),
                else => {},
            }

            const nx: i8 = x2 + switch (c) {
                'L' => @as(i8, -1),
                'R' => @as(i8, 1),
                else => @as(i8, 0),
            };
            const ny: i8 = y2 + switch (c) {
                'U' => @as(i8, -1),
                'D' => @as(i8, 1),
                else => @as(i8, 0),
            };
            if (@abs(nx) + @abs(ny) <= 2) {
                x2 = nx;
                y2 = ny;
            }
        }

        while (i < input.len and (input[i] == '\n' or input[i] == '\r')) : (i += 1) {}

        code1[len1] = @intCast('1' + @as(u8, @intCast(y1 * 3 + x1)));
        len1 += 1;

        code2[len2] = switch (y2) {
            -2 => '1',
            -1 => @intCast('2' + @as(u8, @intCast(x2 + 1))),
            0 => @intCast('5' + @as(u8, @intCast(x2 + 2))),
            1 => @intCast('A' + @as(u8, @intCast(x2 + 1))),
            2 => 'D',
            else => '?',
        };
        len2 += 1;
        if (i >= input.len) break;
    }
    return .{ .p1 = code1, .p2 = code2, .p1_len = len1, .p2_len = len2 };
}

fn old_main_unused() !void {
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
    std.debug.print("Part 1: {s} | Part 2: {s}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
    allocator.free(result.p1);
    allocator.free(result.p2);
}
fn solve_unused(allocator: std.mem.Allocator, input: []const u8) !struct { p1: []const u8, p2: []const u8 } {
    var code1 = try std.ArrayList(u8).initCapacity(allocator, 16);
    defer code1.deinit(allocator);
    var code2 = try std.ArrayList(u8).initCapacity(allocator, 16);
    defer code2.deinit(allocator);

    var x1: i32 = 1;
    var y1: i32 = 1;

    var x2: i32 = -2;
    var y2: i32 = 0;
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        for (line) |c| {

            switch (c) {
                'U' => y1 = @max(0, y1 - 1),
                'D' => y1 = @min(2, y1 + 1),
                'L' => x1 = @max(0, x1 - 1),
                'R' => x1 = @min(2, x1 + 1),
                else => {},
            }

            const nx = x2 + switch (c) {
                'L' => @as(i32, -1),
                'R' => @as(i32, 1),
                else => @as(i32, 0),
            };
            const ny = y2 + switch (c) {
                'U' => @as(i32, -1),
                'D' => @as(i32, 1),
                else => @as(i32, 0),
            };
            if (@abs(nx) + @abs(ny) <= 2) {
                x2 = nx;
                y2 = ny;
            }
        }

const digit1 = '1' + @as(u8, @intCast(y1 * 3 + x1));
        try code1.append(allocator, digit1);

const digit2: u8 = blk: {
            if (y2 == -2) break :blk '1';
            if (y2 == -1) break :blk '2' + @as(u8, @intCast(x2 + 1));
            if (y2 == 0) break :blk '5' + @as(u8, @intCast(x2 + 2));
            if (y2 == 1) break :blk 'A' + @as(u8, @intCast(x2 + 1));
            if (y2 == 2) break :blk 'D';
            break :blk '?';
        };
        try code2.append(allocator, digit2);
    }
    return .{ .p1 = try code1.toOwnedSlice(allocator), .p2 = try code2.toOwnedSlice(allocator) };
}
