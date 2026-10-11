const std = @import("std");
inline fn solve(input: []const u8) struct { p1: i32, p2: i32 } {
    @setRuntimeSafety(false);
    var p1: i32 = 0;
    var p2: i32 = 0;

    var i: usize = 0;
    // Trim trailing newlines/spaces
    var len = input.len;
    while (len > 0 and input[len - 1] <= ' ') : (len -= 1) {}

    // Skip the very first quote
    while (i < len and input[i] != '"') : (i += 1) {}
    i += 1;

    while (i < len) {
        const c = input[i];
        if (c == '\\') {
            if (i + 1 < len and input[i + 1] == 'x') {
                p1 += 3;
                i += 4;
            } else {
                p1 += 1;
                i += 2;
            }
        } else if (c == '"') {
            p1 += 2;
            // Skip closing quote, newline, and next line's opening quote
            i += 1;
            while (i < len and input[i] != '"') : (i += 1) {}
            i += 1; // skip next opening quote
        } else {
            i += 1;
        }
    }

    // Part 2: each quote or backslash adds 1, each newline adds 2
    for (input[0..len]) |c| {
        if (c == '"' or c == '\\') {
            p2 += 1;
        } else if (c == '\n') {
            p2 += 2;
        }
    }
    // Final line also needs 2 enclosing quotes
    p2 += 2;

    return .{ .p1 = p1, .p2 = p2 };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\nPart 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
