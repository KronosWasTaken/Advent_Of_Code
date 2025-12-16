const std = @import("std");

const S = [64]u32{
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9,  14, 20, 5, 9,  14, 20, 5, 9,  14, 20, 5, 9,  14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
};
const K = [64]u32{
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
    0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
    0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
    0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
    0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
    0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
    0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
    0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
    0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
};
const Result = struct { p1: []const u8, p2: u32 };
const State = struct {
    x: i8,
    y: i8,
    path: []u8,
};
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
    std.debug.print("Part 1: {s} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
    allocator.free(result.p1);
}
fn solve(allocator: std.mem.Allocator, input: []const u8) !Result {
    var passcode = std.mem.trim(u8, input, &std.ascii.whitespace);

    if (std.mem.lastIndexOf(u8, passcode, " ")) |idx| {
        passcode = passcode[idx + 1 ..];
    }

    if (passcode.len > 0 and passcode[passcode.len - 1] == '.') {
        passcode = passcode[0..passcode.len - 1];
    }
    var shortest: ?[]const u8 = null;
    var longest: u32 = 0;
    var queue = std.ArrayListUnmanaged(State){};
    defer {
        for (queue.items) |state| {
            allocator.free(state.path);
        }
        queue.deinit(allocator);
    }
    const initial_path = try allocator.dupe(u8, passcode);
    try queue.append(allocator, .{ .x = 0, .y = 0, .path = initial_path });
    var head: usize = 0;
    while (head < queue.items.len) {
        const state = queue.items[head];
        head += 1;
        if (state.x == 3 and state.y == 3) {

            const path_str = state.path[passcode.len..];
            if (shortest == null) {
                shortest = try allocator.dupe(u8, path_str);
            }
            longest = @max(longest, @as(u32, @intCast(path_str.len)));

            continue;
        }
        var hash: [16]u8 = undefined;
        md5Hash(state.path, &hash);

        const doors = [4]u8{ hash[0] >> 4, hash[0] & 0xf, hash[1] >> 4, hash[1] & 0xf };
        const dirs = "UDLR";
        const moves = [_][2]i8{ .{0, -1}, .{0, 1}, .{-1, 0}, .{1, 0} };
        for (0..4) |i| {

            if (doors[i] < 0xb) continue;
            const nx = state.x + moves[i][0];
            const ny = state.y + moves[i][1];
            if (nx < 0 or nx > 3 or ny < 0 or ny > 3) continue;
            var new_path = try allocator.alloc(u8, state.path.len + 1);
            @memcpy(new_path[0..state.path.len], state.path);
            new_path[state.path.len] = dirs[i];
            try queue.append(allocator, .{ .x = nx, .y = ny, .path = new_path });
        }
    }
    return .{ .p1 = shortest orelse try allocator.dupe(u8, ""), .p2 = longest };
}
fn md5Hash(msg: []const u8, out: *[16]u8) void {

    std.crypto.hash.Md5.hash(msg, out, .{});
}
