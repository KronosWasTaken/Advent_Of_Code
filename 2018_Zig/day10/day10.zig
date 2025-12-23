const std = @import("std");

const Result = struct { p1: [9:0]u8, p2: i32 };

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const glyphs = std.StaticStringMap(u8).initComptime(.{
        .{ "0x7e186185f86185f", 'B' },
        .{ "0x4104105f04107f", 'F' },
        .{ "0xfc104105f04107f", 'E' },
        .{ "0x391450410410438", 'J' },
        .{ "0x7a104104104185e", 'C' },
        .{ "0x871c69a659638e1", 'N' },
        .{ "0x86149230c492861", 'X' },
        .{ "0xfc104210842083f", 'Z' },
        .{ "0x861861fe186148c", 'A' },
        .{ "0xbb1861e4104185e", 'G' },
        .{ "0x86186187f861861", 'H' },
        .{ "0x8512450c3149461", 'K' },
        .{ "0xfc1041041041041", 'L' },
        .{ "0x04104105f86185f", 'P' },
        .{ "0x86145125f86185f", 'R' },
    });

    var points = std.ArrayList([4]i32){};
    defer points.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        var nums: [4]i32 = undefined;
        var idx: usize = 0;
        var neg = false;

        while (idx < 4 and i < input.len) {
            if (input[i] == '-') {
                neg = true;
                i += 1;
            } else if (input[i] >= '0' and input[i] <= '9') {
                var n: i32 = 0;
                while (i < input.len and input[i] >= '0' and input[i] <= '9') {
                    n = n * 10 + @as(i32, input[i] - '0');
                    i += 1;
                }
                nums[idx] = if (neg) -n else n;
                idx += 1;
                neg = false;
            } else {
                i += 1;
            }
        }

        if (idx == 4) {
            points.append(allocator, nums) catch unreachable;
        }
    }

    var y_up: i32 = std.math.maxInt(i32);
    var y_down: i32 = std.math.minInt(i32);
    var dy_up: i32 = std.math.maxInt(i32);
    var dy_down: i32 = std.math.minInt(i32);

    for (points.items) |p| {
        if (p[3] < dy_up) {
            dy_up = p[3];
            y_up = p[1];
        } else if (p[3] == dy_up) {
            y_up = @min(y_up, p[1]);
        }

        if (p[3] > dy_down) {
            dy_down = p[3];
            y_down = p[1];
        } else if (p[3] == dy_down) {
            y_down = @max(y_down, p[1]);
        }
    }

    const part2 = 1 + @divTrunc(y_up - y_down, dy_down - dy_up);

    var min_x: i32 = std.math.maxInt(i32);
    var min_y: i32 = std.math.maxInt(i32);

    for (points.items) |*p| {
        p[0] += part2 * p[2];
        p[1] += part2 * p[3];
        min_x = @min(min_x, p[0]);
        min_y = @min(min_y, p[1]);
    }

    for (points.items) |*p| {
        p[0] -= min_x;
        p[1] -= min_y;
    }

    var text = [_]u64{0} ** 8;
    for (points.items) |p| {
        const letter_idx: usize = @intCast(@divTrunc(p[0], 8));
        if (letter_idx < 8) {
            const bit_pos: u6 = @intCast(6 * p[1] + @mod(p[0], 8));
            text[letter_idx] |= @as(u64, 1) << bit_pos;
        }
    }

    var part1: [9:0]u8 = undefined;
    var buf: [20]u8 = undefined;
    for (text, 0..) |pattern, idx| {
        const hex_str = std.fmt.bufPrint(&buf, "0x{x}", .{pattern}) catch unreachable;
        part1[idx] = glyphs.get(hex_str) orelse '?';
    }
    part1[8] = 0;

    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {s}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
