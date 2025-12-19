const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
fn solve(input: []const u8) Result {
    const gpa = std.heap.page_allocator;
    var graph: std.ArrayList(std.ArrayList(u32)) = .{};
    defer {
        for (graph.items) |*list| list.deinit(gpa);
        graph.deinit(gpa);
    }
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        var neighbors: std.ArrayList(u32) = .{};
        const arrow_pos = std.mem.indexOf(u8, line, "<->") orelse continue;
        var tokens = std.mem.tokenizeAny(u8, line[arrow_pos + 3 ..], ", ");
        while (tokens.next()) |token| {
            const num = std.fmt.parseInt(u32, token, 10) catch continue;
            neighbors.append(gpa, num) catch unreachable;
        }
        graph.append(gpa, neighbors) catch unreachable;
    }
    var visited = std.AutoHashMap(u32, void).init(gpa);
    defer visited.deinit();
    var queue: std.ArrayList(u32) = .{};
    defer queue.deinit(gpa);
    queue.append(gpa, 0) catch unreachable;
    visited.put(0, {}) catch unreachable;
    while (queue.items.len > 0) {
        const node = queue.orderedRemove(0);
        if (node < graph.items.len) {
            for (graph.items[node].items) |neighbor| {
                if (!visited.contains(neighbor)) {
                    visited.put(neighbor, {}) catch unreachable;
                    queue.append(gpa, neighbor) catch unreachable;
                }
            }
        }
    }
    const p1 = visited.count();
    var all_visited = std.AutoHashMap(u32, void).init(gpa);
    defer all_visited.deinit();
    var groups: u32 = 0;
    for (0..graph.items.len) |start| {
        const start_u32: u32 = @intCast(start);
        if (all_visited.contains(start_u32)) continue;
        groups += 1;
        queue.clearRetainingCapacity();
        queue.append(gpa, start_u32) catch unreachable;
        all_visited.put(start_u32, {}) catch unreachable;
        while (queue.items.len > 0) {
            const node = queue.orderedRemove(0);
            if (node < graph.items.len) {
                for (graph.items[node].items) |neighbor| {
                    if (!all_visited.contains(neighbor)) {
                        all_visited.put(neighbor, {}) catch unreachable;
                        queue.append(gpa, neighbor) catch unreachable;
                    }
                }
            }
        }
    }
    return .{ .p1 = p1, .p2 = groups };
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