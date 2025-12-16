const std = @import("std");
const Result = struct { p1: u32, p2: []const u8 };
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    const input = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(input);
    var timer = try std.time.Timer.start();
    const result = solve(input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {s}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn solve(input: []const u8) Result {

var lines = std.mem.tokenizeScalar(u8, input, '\n');
    var line_num: usize = 0;
    var first: u32 = 0;
    var second: u32 = 0;
    while (lines.next()) |line| : (line_num += 1) {
        if (line_num == 1) {
            first = parseNumber(line);
        } else if (line_num == 2) {
            second = parseNumber(line);
            break;
        }
    }
    const offset = first * second;

    var result: u32 = 0;
    while (result < offset) {
        result = (result << 2) | 2;
    }
    return .{ .p1 = result - offset, .p2 = "Merry Christmas!" };
}
fn parseNumber(line: []const u8) u32 {
    var result: u32 = 0;
    for (line) |c| {
        if (c >= '0' and c <= '9') {
            result = result * 10 + (c - '0');
        }
    }
    return result;
}
