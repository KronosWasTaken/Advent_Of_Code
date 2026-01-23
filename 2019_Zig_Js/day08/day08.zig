const std = @import("std");

const WIDTH = 25;
const HEIGHT = 6;
const LAYER_SIZE = WIDTH * HEIGHT;

const Result = struct {
    p1: u32,
    p2: []const u8,
};

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var part1: u32 = 0;
    var fewest: u32 = std.math.maxInt(u32);


    var i: usize = 0;
    while (i + LAYER_SIZE <= input.len) {
        var c0: u32 = 0;
        var c1: u32 = 0;
        var c2: u32 = 0;

        const layer = input[i..i+LAYER_SIZE];


        for (layer) |c| {
            c0 += @intFromBool(c == '0');
            c1 += @intFromBool(c == '1');
            c2 += @intFromBool(c == '2');
        }

        if (c0 < fewest) {
            fewest = c0;
            part1 = c1 * c2;
        }

        i += LAYER_SIZE;
    }


    var part2 = try allocator.alloc(u8, (WIDTH + 1) * HEIGHT);
    var pos: usize = 0;

    for (0..HEIGHT) |y| {
        part2[pos] = '\n';
        pos += 1;

        for (0..WIDTH) |x| {
            var idx = WIDTH * y + x;


            while (idx < input.len and input[idx] == '2') {
                idx += LAYER_SIZE;
            }

            part2[pos] = if (idx < input.len and input[idx] == '1') '#' else '.';
            pos += 1;
        }
    }

    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    defer allocator.free(result.p2);

    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {s}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}

