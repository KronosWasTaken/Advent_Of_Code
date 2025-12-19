const std = @import("std");
const Result = struct { p1: u32, p2: []const u8 };
fn knotHash(lengths: []const usize, rounds: usize) [256]u8 {
    var knot: [256]u8 = undefined;
    for (0..256) |i| knot[i] = @intCast(i);
    var position: usize = 0;
    var skip: usize = 0;
    for (0..rounds) |_| {
        for (lengths) |length| {
            const next = length + skip;
            var i: usize = 0;
            while (i < length / 2) : (i += 1) {
                const tmp = knot[i];
                knot[i] = knot[length - 1 - i];
                knot[length - 1 - i] = tmp;
            }
            const rot = next % 256;
            var temp: [256]u8 = undefined;
            for (0..256) |j| {
                temp[j] = knot[(j + rot) % 256];
            }
            knot = temp;
            position += next;
            skip += 1;
        }
    }
    const final_rot = position % 256;
    var temp: [256]u8 = undefined;
    for (0..256) |j| {
        temp[j] = knot[(j + 256 - final_rot) % 256];
    }
    return temp;
}
fn solve(input: []const u8) Result {
    const gpa = std.heap.page_allocator;
    var lengths1: std.ArrayList(usize) = .{};
    defer lengths1.deinit(gpa);
    var tokens = std.mem.tokenizeScalar(u8, input, ',');
    while (tokens.next()) |token| {
        const num = std.fmt.parseInt(usize, std.mem.trim(u8, token, &std.ascii.whitespace), 10) catch continue;
        lengths1.append(gpa, num) catch unreachable;
    }
    const knot1 = knotHash(lengths1.items, 1);
    const p1 = @as(u32, knot1[0]) * @as(u32, knot1[1]);
    var lengths2: std.ArrayList(usize) = .{};
    defer lengths2.deinit(gpa);
    const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);
    for (trimmed) |b| {
        lengths2.append(gpa, b) catch unreachable;
    }
    lengths2.appendSlice(gpa, &[_]usize{ 17, 31, 73, 47, 23 }) catch unreachable;
    const knot2 = knotHash(lengths2.items, 64);
    var result_buf = gpa.alloc(u8, 32) catch unreachable;
    var i: usize = 0;
    while (i < 16) : (i += 1) {
        var xor_val: u8 = 0;
        for (knot2[i * 16 .. (i + 1) * 16]) |byte| {
            xor_val ^= byte;
        }
        _ = std.fmt.bufPrint(result_buf[i * 2 .. i * 2 + 2], "{x:0>2}", .{xor_val}) catch unreachable;
    }
    return .{ .p1 = p1, .p2 = result_buf };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var total: u64 = 0;
    const iterations = 1000;
    var result: Result = undefined;
    for (0..iterations) |_| {
        var timer = try std.time.Timer.start();
        result = solve(input);
        total += timer.read();
    }
    const avg_ns = total / iterations;
    const avg_us = @as(f64, @floatFromInt(avg_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {s}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{avg_us});
}
