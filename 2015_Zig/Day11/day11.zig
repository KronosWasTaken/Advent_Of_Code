const std = @import("std");
inline fn increment(pwd: *[8]u8) void {
    @setRuntimeSafety(false);
    var i: usize = 7;
    while (true) : (i -= 1) {
        if (pwd[i] != 'z') {
            pwd[i] += 1;
            if (pwd[i] == 'i' or pwd[i] == 'o' or pwd[i] == 'l') pwd[i] += 1;
            break;
        }
        pwd[i] = 'a';
        if (i == 0) break;
    }
}
inline fn isValid(pwd: [8]u8) bool {
    @setRuntimeSafety(false);
    const has_straight = 
        (pwd[0] + 1 == pwd[1] and pwd[0] + 2 == pwd[2]) or
        (pwd[1] + 1 == pwd[2] and pwd[1] + 2 == pwd[3]) or
        (pwd[2] + 1 == pwd[3] and pwd[2] + 2 == pwd[4]) or
        (pwd[3] + 1 == pwd[4] and pwd[3] + 2 == pwd[5]) or
        (pwd[4] + 1 == pwd[5] and pwd[4] + 2 == pwd[6]) or
        (pwd[5] + 1 == pwd[6] and pwd[5] + 2 == pwd[7]);
    if (!has_straight) return false;
    var pairs: u8 = 0;
    var i: usize = 0;
    while (i < 7) : (i += 1) {
        if (pwd[i] == pwd[i + 1]) {
            pairs += 1;
            if (pairs == 2) return true;
            i += 1;
        }
    }
    return false;
}
fn solve(input: []const u8) struct { p1: [8]u8, p2: [8]u8 } {
    @setRuntimeSafety(false);
    var pwd: [8]u8 = undefined;
    @memcpy(&pwd, input[0..8]);
    while (true) {
        increment(&pwd);
        if (isValid(pwd)) break;
    }
    const p1 = pwd;
    while (true) {
        increment(&pwd);
        if (isValid(pwd)) break;
    }
    return .{ .p1 = p1, .p2 = pwd };
}
pub fn main() !void {
    const input = "hepxcrrq";
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {s}\nPart 2: {s}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
