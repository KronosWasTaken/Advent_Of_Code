const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
const Point = struct { x: i32, y: i32 };
fn solve(input: []const u8) Result {
    const target = std.fmt.parseInt(u32, std.mem.trim(u8, input, &std.ascii.whitespace), 10) catch unreachable;
    var a: u32 = 3;
    while (a * a < target) : (a += 2) {}
    const b = a - 1;
    const c = a - 2;
    const p1 = (b / 2) + blk: {
        const diff = (target - c * c - 1) % b;
        const center = c / 2;
        break :blk if (diff > center) diff - center else center - diff;
    };
    var map = std.AutoHashMap(Point, u32).init(std.heap.page_allocator);
    defer map.deinit();
    map.put(.{ .x = 0, .y = 0 }, 1) catch unreachable;
    var pos = Point{ .x = 1, .y = 0 };
    var dir = Point{ .x = 0, .y = -1 }; 
    var left = Point{ .x = -1, .y = 0 }; 
    var size: i32 = 2;
    var p2: u32 = 0;
    outer: while (true) {
        var edge: i32 = 0;
        while (edge < 4) : (edge += 1) {
            var i: i32 = 0;
            while (i < size) : (i += 1) {
                const behind = Point{ .x = pos.x - dir.x, .y = pos.y - dir.y };
                const left_forward = Point{ .x = pos.x + left.x + dir.x, .y = pos.y + left.y + dir.y };
                const left_side = Point{ .x = pos.x + left.x, .y = pos.y + left.y };
                const left_back = Point{ .x = pos.x + left.x - dir.x, .y = pos.y + left.y - dir.y };
                const sum = (map.get(behind) orelse 0) +
                           (map.get(left_forward) orelse 0) +
                           (map.get(left_side) orelse 0) +
                           (map.get(left_back) orelse 0);
                if (sum > target) {
                    p2 = sum;
                    break :outer;
                }
                map.put(pos, sum) catch unreachable;
                if (i == size - 1 and edge < 3) {
                    pos.x += left.x;
                    pos.y += left.y;
                } else {
                    pos.x += dir.x;
                    pos.y += dir.y;
                }
            }
            dir = left;
            left = Point{ .x = left.y, .y = -left.x }; 
        }
        size += 2;
    }
    return .{ .p1 = p1, .p2 = p2 };
}
pub fn main() !void {
    const input = "361527";
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
