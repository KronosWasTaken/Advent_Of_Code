const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

fn vectorMask(chunk: [32]u8) u32 {
    const vec: @Vector(32, u8) = @bitCast(chunk);
    const eq = vec == @as(@Vector(32, u8), @splat(@as(u8, '#')));
    var mask: u32 = 0;
    inline for (0..32) |idx| {
        mask |= (@as(u32, @intFromBool(eq[idx])) << @intCast(idx));
    }
    return mask;
}

fn parseRows(allocator: std.mem.Allocator, input: []const u8) ![]u32 {
    var rows = std.ArrayListUnmanaged(u32){};
    errdefer rows.deinit(allocator);

    var width: usize = 0;
    while (width < input.len and input[width] != '\n' and input[width] != '\r') : (width += 1) {}
    if (width == 0) return rows.toOwnedSlice(allocator);

    var i: usize = 0;
    while (i + width <= input.len) {
        if (input[i] == '\n' or input[i] == '\r') {
            i += 1;
            continue;
        }

        var mask: u32 = 0;
        if (width <= 32) {
            if (i + 32 <= input.len) {
                const ptr = @as(*const [32]u8, @ptrCast(input.ptr + i));
                mask = vectorMask(ptr.*);
            } else {
                var chunk: [32]u8 = [_]u8{0} ** 32;
                std.mem.copyForwards(u8, chunk[0..width], input[i .. i + width]);
                mask = vectorMask(chunk);
            }
            if (width < 32) {
                mask &= (@as(u32, 1) << @intCast(width)) - 1;
            }
        } else {
            var bit: u32 = 1;
            var j: usize = 0;
            while (j < width) : (j += 1) {
                if (input[i + j] == '#') mask |= bit;
                bit <<= 1;
            }
        }

        try rows.append(allocator, mask);
        i += width;
        if (i < input.len and input[i] == '\r') i += 1;
        if (i < input.len and input[i] == '\n') i += 1;
    }

    return rows.toOwnedSlice(allocator);
}

fn treesHit(rows: []const u32, width: usize, dx: usize, dy: usize) usize {
    var shift: usize = 0;
    var count: usize = 0;
    var i: usize = 0;
    while (i < rows.len) : (i += dy) {
        count += (rows[i] >> @intCast(shift)) & 1;
        shift += dx;
        if (shift >= width) shift -= width;
    }
    return count;
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var width: usize = 0;
    while (width < input.len and input[width] != '\n' and input[width] != '\r') : (width += 1) {}
    const rows = parseRows(arena.allocator(), input) catch unreachable;

    const p1 = treesHit(rows, width, 3, 1);
    const p2 = p1 * treesHit(rows, width, 1, 1) * treesHit(rows, width, 5, 1) * treesHit(rows, width, 7, 1) * treesHit(rows, width, 1, 2);

    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
