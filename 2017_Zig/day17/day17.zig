const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
fn solve(input: []const u8) Result {
    const steps = std.fmt.parseInt(usize, std.mem.trim(u8, input, &std.ascii.whitespace), 10) catch 0;
    const gpa = std.heap.page_allocator;
    var buffer: std.ArrayList(u32) = .{};
    defer buffer.deinit(gpa);
    buffer.append(gpa, 0) catch unreachable;
    var pos: usize = 0;
    for (1..2018) |i| {
        pos = (pos + steps) % buffer.items.len + 1;
        buffer.insert(gpa, pos, @intCast(i)) catch unreachable;
    }
    const p1 = buffer.items[(pos + 1) % buffer.items.len];
    var p2: u32 = 0;
    pos = 0;
    var n: usize = 1;
    while (n <= 50_000_000) {
        if (pos == 0) {
            p2 = @intCast(n);
        }
        const skip = (n - pos + steps) / (steps + 1);
        n += skip;
        pos = (pos + skip * (steps + 1)) % n;
    }
    return .{ .p1 = p1, .p2 = p2 };
}
pub fn main() !void {
    const input = "304";
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}