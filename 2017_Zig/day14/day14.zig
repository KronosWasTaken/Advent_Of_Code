const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
fn knotHash(input: []const u8) [16]u8 {
    var lengths: [256]u8 = undefined;
    var len_count: usize = 0;
    for (input) |b| {
        lengths[len_count] = b;
        len_count += 1;
    }
    lengths[len_count] = 17; len_count += 1;
    lengths[len_count] = 31; len_count += 1;
    lengths[len_count] = 73; len_count += 1;
    lengths[len_count] = 47; len_count += 1;
    lengths[len_count] = 23; len_count += 1;
    var knot: [256]u8 = undefined;
    for (0..256) |i| knot[i] = @intCast(i);
    var position: usize = 0;
    var skip: usize = 0;
    for (0..64) |_| {
        for (lengths[0..len_count]) |length| {
            const len: usize = length;
            var i: usize = 0;
            while (i < len / 2) : (i += 1) {
                const a_idx = (position + i) % 256;
                const b_idx = (position + len - 1 - i) % 256;
                const tmp = knot[a_idx];
                knot[a_idx] = knot[b_idx];
                knot[b_idx] = tmp;
            }
            position = (position + len + skip) % 256;
            skip += 1;
        }
    }
    var hash: [16]u8 = undefined;
    for (0..16) |i| {
        var xor_val: u8 = 0;
        for (0..16) |j| {
            xor_val ^= knot[i * 16 + j];
        }
        hash[i] = xor_val;
    }
    return hash;
}
fn floodFill(grid: *[128][128]bool, row: usize, col: usize) void {
    grid[row][col] = false;
    if (row > 0 and grid[row - 1][col]) {
        floodFill(grid, row - 1, col);
    }
    if (row < 127 and grid[row + 1][col]) {
        floodFill(grid, row + 1, col);
    }
    if (col > 0 and grid[row][col - 1]) {
        floodFill(grid, row, col - 1);
    }
    if (col < 127 and grid[row][col + 1]) {
        floodFill(grid, row, col + 1);
    }
}
fn solve(input: []const u8) Result {
    const gpa = std.heap.page_allocator;
    const key = std.mem.trim(u8, input, &std.ascii.whitespace);
    var grid: [128][128]bool = undefined;
    var p1: u32 = 0;
    for (0..128) |row| {
        var hash_input: std.ArrayList(u8) = .{};
        defer hash_input.deinit(gpa);
        hash_input.appendSlice(gpa, key) catch unreachable;
        hash_input.append(gpa, '-') catch unreachable;
        var buf: [16]u8 = undefined;
        const row_str = std.fmt.bufPrint(&buf, "{}", .{row}) catch unreachable;
        hash_input.appendSlice(gpa, row_str) catch unreachable;
        const hash = knotHash(hash_input.items);
        for (hash, 0..) |byte, i| {
            for (0..8) |bit| {
                const col = i * 8 + bit;
                const is_set = (byte >> @intCast(7 - bit)) & 1 == 1;
                grid[row][col] = is_set;
                if (is_set) p1 += 1;
            }
        }
    }
    var p2: u32 = 0;
    for (0..128) |row| {
        for (0..128) |col| {
            if (grid[row][col]) {
                p2 += 1;
                floodFill(&grid, row, col);
            }
        }
    }
    return .{ .p1 = p1, .p2 = p2 };
}
pub fn main() !void {
    const input = "hwlqcszp";
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}