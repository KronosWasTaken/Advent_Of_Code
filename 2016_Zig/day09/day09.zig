const std = @import("std");
const Result = struct { p1: u64, p2: u64 };
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
    const result = decompress(input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn solve(input: []const u8) Result {
    @setRuntimeSafety(false);
    const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);
    return .{ .p1 = decompress(trimmed, false), .p2 = decompress(trimmed, true) };
}
fn decompress(input: []const u8, recursive: bool) u64 {
    var length: u64 = 0;
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '(') {
            i += 1;
            var chars: usize = 0;
            while (input[i] != 'x') : (i += 1) {
                chars = chars * 10 + (input[i] - '0');
            }
            i += 1;
            var times: u64 = 0;
            while (input[i] != ')') : (i += 1) {
                times = times * 10 + (input[i] - '0');
            }
            i += 1;
            const segment = input[i .. i + chars];
            const segment_len = if (recursive) decompress(segment, true) else chars;
            length += segment_len * times;
            i += chars;
        } else {
            length += 1;
            i += 1;
        }
    }
    return length;
}
