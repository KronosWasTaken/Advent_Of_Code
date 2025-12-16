const std = @import("std");
const Result = struct { p1: []const u8, p2: []const u8 };
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = "10111100110001111";
    var timer = try std.time.Timer.start();
    const result = try solve(allocator, input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {s} | Part 2: {s}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
    allocator.free(result.p1);
    allocator.free(result.p2);
}
fn solve(allocator: std.mem.Allocator, input: []const u8) !Result {
    const initial = std.mem.trim(u8, input, &std.ascii.whitespace);

    var ones = std.ArrayListUnmanaged(usize){};
    defer ones.deinit(allocator);
    try ones.append(allocator, 0);
    var sum: usize = 0;
    for (initial) |c| {
        sum += if (c == '1') 1 else 0;
        try ones.append(allocator, sum);
    }

    const p1 = try checksum(allocator, ones.items, 1 << 4);

    const p2 = try checksum(allocator, ones.items, 1 << 21);
    return .{ .p1 = p1, .p2 = p2 };
}
fn checksum(allocator: std.mem.Allocator, ones: []const usize, step_size: usize) ![]const u8 {
    var result = try allocator.alloc(u8, 17);
    for (0..17) |i| {
        const count1 = count(ones, i * step_size);
        const count2 = count(ones, (i + 1) * step_size);
        result[i] = if ((count2 - count1) % 2 == 0) '1' else '0';
    }
    return result;
}
fn count(ones: []const usize, length_param: usize) usize {
    var length = length_param;
    var half = ones.len - 1;
    var full = 2 * half + 1;

    while (full < length) {
        half = full;
        full = 2 * half + 1;
    }
    var result: usize = 0;
    while (length >= ones.len) {

        while (length <= half) {
            half /= 2;
            full /= 2;
        }

        const next = full - length;
        result += half - next;
        length = next;
    }
    return result + ones[length];
}
