const std = @import("std");
const Result = struct { p1: [256]u8, p1_len: usize, p2: u32 };
fn solve(input: []const u8) Result {
    const gpa = std.heap.page_allocator;
    var grid: std.ArrayList([]const u8) = .{};
    defer grid.deinit(gpa);
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        grid.append(gpa, line) catch unreachable;
    }
    var row: isize = 0;
    var col: isize = @intCast(std.mem.indexOfScalar(u8, grid.items[0], '|') orelse 0);
    var dr: isize = 1;
    var dc: isize = 0;
    var letters: std.ArrayList(u8) = .{};
    defer letters.deinit(gpa);
    var steps: u32 = 0;
    while (true) {
        if (row < 0 or row >= grid.items.len) break;
        if (col < 0 or col >= grid.items[@intCast(row)].len) break;
        const cell = grid.items[@intCast(row)][@intCast(col)];
        if (cell == ' ') break;
        steps += 1;
        if (cell >= 'A' and cell <= 'Z') {
            letters.append(gpa, cell) catch unreachable;
        } else if (cell == '+') {
            if (dc != 0) {
                if (row > 0 and row - 1 < grid.items.len) {
                    if (col >= 0 and col < grid.items[@intCast(row - 1)].len) {
                        if (grid.items[@intCast(row - 1)][@intCast(col)] != ' ') {
                            dr = -1;
                            dc = 0;
                        }
                    }
                }
                if (dr == 0 and row + 1 < grid.items.len) {
                    if (col >= 0 and col < grid.items[@intCast(row + 1)].len) {
                        if (grid.items[@intCast(row + 1)][@intCast(col)] != ' ') {
                            dr = 1;
                            dc = 0;
                        }
                    }
                }
            } else {
                if (col > 0 and col - 1 < grid.items[@intCast(row)].len) {
                    if (grid.items[@intCast(row)][@intCast(col - 1)] != ' ') {
                        dr = 0;
                        dc = -1;
                    }
                }
                if (dc == 0 and col + 1 < grid.items[@intCast(row)].len) {
                    if (grid.items[@intCast(row)][@intCast(col + 1)] != ' ') {
                        dr = 0;
                        dc = 1;
                    }
                }
            }
        }
        row += dr;
        col += dc;
    }
    var result_letters: [256]u8 = undefined;
    @memcpy(result_letters[0..letters.items.len], letters.items);
    return .{ .p1 = result_letters, .p1_len = letters.items.len, .p2 = steps };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {s} | Part 2: {}\n", .{ result.p1[0..result.p1_len], result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
