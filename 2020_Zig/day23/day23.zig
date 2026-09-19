const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

const Cup = u32;

fn parseInput(allocator: std.mem.Allocator, input: []const u8) ![]Cup {
    var list = std.ArrayListUnmanaged(Cup){};
    errdefer list.deinit(allocator);

    for (input) |char| {
        if (char >= '1' and char <= '9') {
            try list.append(allocator, @as(Cup, char - '0'));
        }
    }

    return list.toOwnedSlice(allocator);
}

fn play(cups: []Cup, start: usize, rounds: usize) void {
    @setRuntimeSafety(false);
    var current = start;
    const max = cups.len - 1;

    var i: usize = 0;
    while (i < rounds) : (i += 1) {
        const a = @as(usize, cups[current]);
        const b = @as(usize, cups[a]);
        const c = @as(usize, cups[b]);
        const next_cur = @as(usize, cups[c]);

        var dest = current - 1;
        if (dest == 0 or dest == a or dest == b or dest == c) {
            if (dest == 0) {
                dest = max;
            }
            while (dest == a or dest == b or dest == c) {
                dest -= 1;
                if (dest == 0) {
                    dest = max;
                }
            }
        }

        cups[current] = @intCast(next_cur);
        cups[c] = cups[dest];
        cups[dest] = @intCast(a);
        current = next_cur;
    }
}

fn part1(input: []const Cup, allocator: std.mem.Allocator) !usize {
    const start = @as(usize, input[0]);
    const cups = try allocator.alloc(Cup, 10);
    defer allocator.free(cups);
    @memset(cups, 0);

    var current = start;
    for (input[1..]) |next| {
        cups[current] = next;
        current = @as(usize, next);
    }
    cups[current] = @intCast(start);
    play(cups, start, 100);

    var value: usize = 0;
    var x: usize = 1;
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        x = @as(usize, cups[x]);
        value = value * 10 + x;
    }
    return value;
}

fn part2(input: []const Cup, allocator: std.mem.Allocator) !usize {
    const max: usize = 1_000_000;
    const start = @as(usize, input[0]);
    const cups = try allocator.alloc(Cup, max + 1);
    defer allocator.free(cups);

    var i: usize = 0;
    while (i <= max) : (i += 1) {
        cups[i] = @intCast(i + 1);
    }

    var current = start;
    for (input[1..]) |next| {
        cups[current] = next;
        current = @as(usize, next);
    }
    cups[current] = 10;
    cups[max] = @intCast(start);
    play(cups, start, 10_000_000);

    const first = @as(usize, cups[1]);
    const second = @as(usize, cups[first]);
    return first * second;
}

fn solve(input_data: []const u8) !Result {
    const allocator = std.heap.page_allocator;

    const cups = try parseInput(allocator, input_data);
    defer allocator.free(cups);
    if (cups.len == 0) {
        return .{ .p1 = 0, .p2 = 0 };
    }

    const p1 = try part1(cups, allocator);
    const p2 = try part2(cups, allocator);
    return .{
        .p1 = p1,
        .p2 = p2,
    };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const result = try solve(input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;

    std.debug.print("Part 1: {}\nPart 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
