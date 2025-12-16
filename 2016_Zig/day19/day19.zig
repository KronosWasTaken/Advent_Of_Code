const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
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
    const result = solve(input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn solve(input: []const u8) Result {
    @setRuntimeSafety(false);
    var n: u32 = 0;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            n = n * 10 + (c - '0');
        }
    }

    var elf = n;
    elf *= 2;
    elf -= @as(u32, 1) << @intCast(@as(u5, @intCast(31 - @clz(elf))));
    elf += 1;
    const p1 = elf;

    elf = 0;
    var size: u32 = 1;
    while (size < n) {
        const remaining = n - size;
        if (elf > size / 2) {
            const possible = 2 * elf - size;
            size += @min(possible, remaining);
        } else {
            if (elf >= remaining) {
                elf -= remaining;
                size += remaining;
            } else {
                elf += size;
                size = elf + 1;
            }
        }
    }
    const p2 = n - elf;
    return .{ .p1 = p1, .p2 = p2 };
}
