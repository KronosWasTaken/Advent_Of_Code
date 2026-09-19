const std = @import("std");

inline fn getDoors(msg: []const u8) [4]bool {
    var hash: [16]u8 = undefined;
    std.crypto.hash.Md5.hash(msg, &hash, .{});
    return .{
        hash[0] >= 0xb0,
        (hash[0] & 0x0f) >= 0x0b,
        hash[1] >= 0xb0,
        (hash[1] & 0x0f) >= 0x0b,
    };
}

const DIRS = "UDLR";
const DX = [4]i8{ 0, 0, -1, 1 };
const DY = [4]i8{ -1, 1, 0, 0 };

fn dfsLongest(buf: []u8, len: usize, x: i8, y: i8, max_len: *u32) void {
    if (x == 3 and y == 3) {
        max_len.* = @max(max_len.*, @as(u32, @intCast(len)));
        return;
    }

    const doors = getDoors(buf[0..len]);

    inline for (0..4) |i| {
        if (doors[i]) {
            const nx = x + DX[i];
            const ny = y + DY[i];
            if (nx >= 0 and nx <= 3 and ny >= 0 and ny <= 3) {
                buf[len] = DIRS[i];
                dfsLongest(buf, len + 1, nx, ny, max_len);
            }
        }
    }
}

pub fn main() !void {
    const raw = @embedFile("input.txt");
    const passcode = std.mem.trim(u8, raw, " \r\n\t.");

    var timer = try std.time.Timer.start();

    // Part 1: BFS for shortest path (zero heap allocations)
    var node_parent: [2048]u16 = undefined;
    var node_dir: [2048]u8 = undefined;
    var node_x: [2048]i8 = undefined;
    var node_y: [2048]i8 = undefined;

    var queue_head: usize = 0;
    var queue_tail: usize = 1;
    node_x[0] = 0;
    node_y[0] = 0;
    node_parent[0] = 0;

    var p1_buf: [128]u8 = undefined;
    var p1_len: usize = 0;

    var work_buf: [256]u8 = undefined;
    @memcpy(work_buf[0..passcode.len], passcode);

    while (queue_head < queue_tail) {
        const cur_idx = queue_head;
        queue_head += 1;

        const x = node_x[cur_idx];
        const y = node_y[cur_idx];

        if (x == 3 and y == 3) {
            var trace = cur_idx;
            var path_rev: [128]u8 = undefined;
            var rev_len: usize = 0;
            while (trace != 0) {
                path_rev[rev_len] = node_dir[trace];
                rev_len += 1;
                trace = node_parent[trace];
            }
            p1_len = rev_len;
            for (0..rev_len) |k| {
                p1_buf[k] = path_rev[rev_len - 1 - k];
            }
            break;
        }

        var trace = cur_idx;
        var rev_len: usize = 0;
        var path_rev: [128]u8 = undefined;
        while (trace != 0) {
            path_rev[rev_len] = node_dir[trace];
            rev_len += 1;
            trace = node_parent[trace];
        }
        for (0..rev_len) |k| {
            work_buf[passcode.len + k] = path_rev[rev_len - 1 - k];
        }
        const cur_total_len = passcode.len + rev_len;

        const doors = getDoors(work_buf[0..cur_total_len]);

        inline for (0..4) |i| {
            if (doors[i]) {
                const nx = x + DX[i];
                const ny = y + DY[i];
                if (nx >= 0 and nx <= 3 and ny >= 0 and ny <= 3) {
                    node_x[queue_tail] = nx;
                    node_y[queue_tail] = ny;
                    node_parent[queue_tail] = @intCast(cur_idx);
                    node_dir[queue_tail] = DIRS[i];
                    queue_tail += 1;
                }
            }
        }
    }

    // Part 2: DFS for longest path (zero heap allocations)
    var p2_buf: [1024]u8 = undefined;
    @memcpy(p2_buf[0..passcode.len], passcode);
    var max_path_len: u32 = 0;
    dfsLongest(&p2_buf, passcode.len, 0, 0, &max_path_len);
    const p2 = max_path_len - @as(u32, @intCast(passcode.len));

    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {s} | Part 2: {}\n", .{ p1_buf[0..p1_len], p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
