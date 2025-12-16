const std = @import("std");
const Result = struct { p1: [16]u8, p2: [16]u8, p1_len: usize, p2_len: usize };
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const result = solve(input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {s} | Part 2: {s}\n", .{ result.p1[0..result.p1_len], result.p2[0..result.p2_len] });
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
    std.debug.print("Part 1: {s} | Part 2: {s}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
    allocator.free(result.p1);
    allocator.free(result.p2);
}
fn solve(input: []const u8) Result {
    @setRuntimeSafety(false);

    var width: usize = 0;
    while (width < input.len and input[width] != '\n' and input[width] != '\r') : (width += 1) {}
    var stride: usize = width + 1;
    if (width + 1 < input.len and input[width] == '\r' and input[width + 1] == '\n') {
        stride = width + 2;
    }
    var msg1: [16]u8 = undefined;
    var msg2: [16]u8 = undefined;
    for (0..width) |col| {
        var freq = [_]u16{0} ** 26;
        var offset = col;
        while (offset < input.len) : (offset += stride) {
            const c = input[offset];
            if (c >= 'a' and c <= 'z') {
                freq[c - 'a'] += 1;
            }
        }
        var max_idx: u8 = 0;
        var max_count: u16 = 0;
        var min_idx: u8 = 0;
        var min_count: u16 = std.math.maxInt(u16);
        for (freq, 0..) |count, i| {
            if (count > 0) {
                if (count > max_count) {
                    max_count = count;
                    max_idx = @intCast(i);
                }
                if (count < min_count) {
                    min_count = count;
                    min_idx = @intCast(i);
                }
            }
        }
        msg1[col] = 'a' + max_idx;
        msg2[col] = 'a' + min_idx;
    }
    return .{ .p1 = msg1, .p2 = msg2, .p1_len = width, .p2_len = width };
}
