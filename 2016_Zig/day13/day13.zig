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
    const result = try solve(allocator, input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn solve(input: []const u8) Result {
    @setRuntimeSafety(false);

    var fav: u32 = 0;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            fav = fav * 10 + (c - '0');
        }
    }

    var maze = [_][52]bool{[_]bool{false} ** 52} ** 52;

    for (0..52) |x| {
        for (0..52) |y| {
            const n = x * x + 3 * x + 2 * x * y + y + y * y + fav;
            maze[x][y] = @popCount(n) & 1 == 0;
        }
    }
    var queue: [4096][3]u32 = undefined;
    var head: usize = 0;
    var tail: usize = 0;
    queue[tail] = .{ 1, 1, 0 };
    tail += 1;
    maze[1][1] = false;
    var p1: u32 = 0;
    var p2: u32 = 0;
    while (head < tail) {
        const item = queue[head];
        head += 1;
        const x = item[0];
        const y = item[1];
        const cost = item[2];
        if (x == 31 and y == 39) p1 = cost;
        if (cost <= 50) p2 += 1;
        if (x > 0 and maze[x - 1][y]) {
            queue[tail] = .{ x - 1, y, cost + 1 };
            tail += 1;
            maze[x - 1][y] = false;
        }
        if (y > 0 and maze[x][y - 1]) {
            queue[tail] = .{ x, y - 1, cost + 1 };
            tail += 1;
            maze[x][y - 1] = false;
        }
        if (x < 51 and maze[x + 1][y]) {
            queue[tail] = .{ x + 1, y, cost + 1 };
            tail += 1;
            maze[x + 1][y] = false;
        }
        if (y < 51 and maze[x][y + 1]) {
            queue[tail] = .{ x, y + 1, cost + 1 };
            tail += 1;
            maze[x][y + 1] = false;
        }
    }
    return .{ .p1 = p1, .p2 = p2 };
}
