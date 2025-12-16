const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
pub fn main() !void {
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
fn solve(allocator: std.mem.Allocator, input: []const u8) !Result {
    var grid = try std.ArrayList([]const u8).initCapacity(allocator, 64);
    defer grid.deinit(allocator);
    var locations: [8][2]u32 = undefined;
    var num_locs: usize = 0;
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    var y: u32 = 0;
    while (lines.next()) |line| : (y += 1) {
        try grid.append(allocator, line);
        for (line, 0..) |c, x| {
            if (c >= '0' and c <= '7') {
                const idx = c - '0';
                locations[idx] = .{@intCast(x), y};
                num_locs = @max(num_locs, idx + 1);
            }
        }
    }

    var dist: [8][8]u32 = undefined;
    for (0..num_locs) |i| {
        const d = try bfs(allocator, grid.items, locations[i]);
        for (0..num_locs) |j| {
            dist[i][j] = d[j];
        }
    }

    var p1: u32 = std.math.maxInt(u32);
    var p2: u32 = std.math.maxInt(u32);
    var perm: [7]u8 = undefined;
    for (0..num_locs - 1) |i| {
        perm[i] = @intCast(i + 1);
    }

    var done = false;
    while (!done) {
        var cost: u32 = dist[0][perm[0]];
        for (0..num_locs - 2) |i| {
            cost += dist[perm[i]][perm[i + 1]];
        }
        p1 = @min(p1, cost);
        p2 = @min(p2, cost + dist[perm[num_locs - 2]][0]);
        done = !nextPermutation(perm[0..num_locs - 1]);
    }
    return .{ .p1 = p1, .p2 = p2 };
}
fn bfs(allocator: std.mem.Allocator, grid: []const []const u8, start: [2]u32) ![8]u32 {
    var distances = [_]u32{std.math.maxInt(u32)} ** 8;
    var queue = try std.ArrayList([2]u32).initCapacity(allocator, 1024);
    defer queue.deinit(allocator);
    var visited = std.AutoHashMap([2]u32, u32).init(allocator);
    defer visited.deinit();
    try queue.append(allocator, start);
    try visited.put(start, 0);
    var idx: usize = 0;
    while (idx < queue.items.len) : (idx += 1) {
        const pos = queue.items[idx];
        const steps = visited.get(pos).?;
        const c = grid[pos[1]][pos[0]];
        if (c >= '0' and c <= '7') {
            distances[c - '0'] = steps;
        }
        const dirs = [_][2]i32{ .{0, 1}, .{0, -1}, .{1, 0}, .{-1, 0} };
        for (dirs) |dir| {
            const nx = @as(i32, @intCast(pos[0])) + dir[0];
            const ny = @as(i32, @intCast(pos[1])) + dir[1];
            if (nx < 0 or ny < 0 or ny >= grid.len or nx >= grid[@intCast(ny)].len) continue;
            const next: [2]u32 = .{@intCast(nx), @intCast(ny)};
            if (visited.contains(next)) continue;
            if (grid[@intCast(ny)][@intCast(nx)] == '#') continue;
            try visited.put(next, steps + 1);
            try queue.append(allocator, next);
        }
    }
    return distances;
}
fn nextPermutation(arr: []u8) bool {
    if (arr.len < 2) return false;
    var i: usize = arr.len - 1;
    while (i > 0) : (i -= 1) {
        if (arr[i - 1] < arr[i]) {
            var j: usize = arr.len - 1;
            while (arr[j] <= arr[i - 1]) : (j -= 1) {}
            std.mem.swap(u8, &arr[i - 1], &arr[j]);
            std.mem.reverse(u8, arr[i..]);
            return true;
        }
    }
    return false;
}
