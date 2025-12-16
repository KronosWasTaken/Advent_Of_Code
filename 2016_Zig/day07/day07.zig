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
fn solve(input: []const u8) Result {
    @setRuntimeSafety(false);
    var p1: u32 = 0;
    var p2: u32 = 0;
    var aba = [_]u16{0xFFFF} ** 676;
    var bab = [_]u16{0xFFFF} ** 676;
    var version: u16 = 0;
    var i: usize = 0;
    while (i < input.len) {
        const line_start = i;
        while (i < input.len and input[i] != '\n') : (i += 1) {}
        const line = input[line_start..i];
        i += 1;
        if (line.len == 0) continue;
        var any_abba_outside = false;
        var any_abba_inside = false;
        var inside = false;
        var supports_ssl = false;
        var j: usize = 0;
        while (j < line.len) : (j += 1) {
            const c0 = line[j];
            if (c0 >= 'a' and c0 <= 'z') {
                if (j + 3 < line.len) {
                    const c1 = line[j + 1];
                    const c2 = line[j + 2];
                    const c3 = line[j + 3];
                    if (c0 == c3 and c1 == c2 and c0 != c1) {
                        if (inside) {
                            any_abba_inside = true;
                        } else {
                            any_abba_outside = true;
                        }
                    }
                }
                if (j + 2 < line.len) {
                    const c1 = line[j + 1];
                    const c2 = line[j + 2];
                    if (c0 == c2 and c0 != c1 and c1 >= 'a' and c1 <= 'z') {
                        const first: u16 = c0 - 'a';
                        const second: u16 = c1 - 'a';
                        if (inside) {
                            const idx = 26 * second + first;
                            bab[idx] = version;
                            if (aba[idx] == version) supports_ssl = true;
                        } else {
                            const idx = 26 * first + second;
                            aba[idx] = version;
                            if (bab[idx] == version) supports_ssl = true;
                        }
                    }
                }
            } else {
                inside = (c0 == '[');
            }
        }
        if (any_abba_outside and !any_abba_inside) p1 += 1;
        if (supports_ssl) p2 += 1;
        version += 1;
    }
    return .{ .p1 = p1, .p2 = p2 };
}
