const std = @import("std");
const Result = struct { p1: i32, p2: i32 };
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn solve(input: []const u8) Result {
    @setRuntimeSafety(false);

    var visited = std.AutoHashMap(i32, void).init(std.heap.page_allocator);
    defer visited.deinit();
    visited.ensureTotalCapacity(1000) catch unreachable;
    var x: i32 = 0;
    var y: i32 = 0;
    var dir: u8 = 0;
    var p2: i32 = 0;
    var found_p2 = false;

    visited.put(0, {}) catch unreachable;
    var i: usize = 0;
    while (i < input.len) {
        const b = input[i];
        if (b != 'L' and b != 'R') {
            i += 1;
            continue;
        }

        dir = if (b == 'L') (dir +% 3) & 3 else (dir +% 1) & 3;
        i += 1;

        var dist: i32 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            dist = dist * 10 + (input[i] - '0');
        }

        const dx: i32 = if (dir == 1) 1 else if (dir == 3) -1 else 0;
        const dy: i32 = if (dir == 0) 1 else if (dir == 2) -1 else 0;

        if (!found_p2) {
            for (0..@intCast(dist)) |_| {
                x += dx;
                y += dy;
                const key = (x << 16) | (y & 0xFFFF);
                const gop = visited.getOrPut(key) catch unreachable;
                if (gop.found_existing) {
                    p2 = @as(i32, @intCast(@abs(x))) + @as(i32, @intCast(@abs(y)));
                    found_p2 = true;
                    break;
                }
            }

            if (found_p2) {
                const rem = dist - @as(i32, @intCast(visited.count() - 1));
                x += dx * @max(0, rem);
                y += dy * @max(0, rem);
            }
        } else {
            x += dx * dist;
            y += dy * dist;
        }
        i += 1;
    }
    return .{ .p1 = @as(i32, @intCast(@abs(x))) + @as(i32, @intCast(@abs(y))), .p2 = p2 };
}
