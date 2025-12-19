const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
fn solve(input: []const u8) Result {
    var groups: u32 = 0;
    var depth: u32 = 1;
    var characters: u32 = 0;
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        const b = input[i];
        switch (b) {
            '<' => {
                i += 1;
                while (i < input.len) : (i += 1) {
                    const c = input[i];
                    switch (c) {
                        '!' => i += 1,
                        '>' => break,
                        else => characters += 1,
                    }
                }
            },
            '{' => {
                groups += depth;
                depth += 1;
            },
            '}' => {
                depth -= 1;
            },
            else => {},
        }
    }
    return .{ .p1 = groups, .p2 = characters };
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
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{avg_us});
}
