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
    var nodes = try std.ArrayList(Node).initCapacity(allocator, 128);
    defer nodes.deinit(allocator);
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "/dev/grid")) continue;
        var it = std.mem.tokenizeAny(u8, line, " T");
        const path = it.next().?;
        const size = try std.fmt.parseInt(u32, it.next().?, 10);
        const used = try std.fmt.parseInt(u32, it.next().?, 10);
        const avail = try std.fmt.parseInt(u32, it.next().?, 10);
        _ = it.next();

        var path_it = std.mem.tokenizeAny(u8, path, "xy-");
        _ = path_it.next();
        const x = try std.fmt.parseInt(u32, path_it.next().?, 10);
        const y = try std.fmt.parseInt(u32, path_it.next().?, 10);
        try nodes.append(allocator, .{ .x = x, .y = y, .size = size, .used = used, .avail = avail });
    }

var used_list = try std.ArrayList(u32).initCapacity(allocator, nodes.items.len);
    defer used_list.deinit(allocator);
    for (nodes.items) |node| {
        if (node.used > 0) {
            try used_list.append(allocator, node.used);
        }
    }
    std.mem.sort(u32, used_list.items, {}, std.sort.asc(u32));

    var avail_list = try std.ArrayList(u32).initCapacity(allocator, nodes.items.len);
    defer avail_list.deinit(allocator);
    for (nodes.items) |node| {
        try avail_list.append(allocator, node.avail);
    }
    std.mem.sort(u32, avail_list.items, {}, std.sort.asc(u32));

    var p1: u32 = 0;
    var i: usize = 0;
    for (used_list.items) |used_val| {

        while (i < avail_list.items.len and avail_list.items[i] < used_val) {
            i += 1;
        }

        p1 += @intCast(avail_list.items.len - i);
    }

var empty_x: u32 = 0;
    var empty_y: u32 = 0;
    var max_x: u32 = 0;
    var wall_x: u32 = std.math.maxInt(u32);
    for (nodes.items) |node| {
        max_x = @max(max_x, node.x);
        if (node.used == 0) {
            empty_x = node.x;
            empty_y = node.y;
        }

        if (node.used >= 100) {
            wall_x = @min(wall_x, node.x - 1);
        }
    }

const a = empty_x - wall_x;

    const b = empty_y;

    const c = (max_x - 1) - wall_x;

    const d = 1;

    const e = 5 * (max_x - 1);
    const p2 = a + b + c + d + e;
    return .{ .p1 = p1, .p2 = p2 };
}
const Node = struct {
    x: u32,
    y: u32,
    size: u32,
    used: u32,
    avail: u32,
};
