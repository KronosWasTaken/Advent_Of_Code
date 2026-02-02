const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

const FirstHash = [_]usize{ 43, 63, 78, 86, 92, 95, 98, 130, 294, 320, 332, 390, 401, 404, 475, 487, 554, 572 };
const SecondHash = [_]usize{ 16, 31, 37, 38, 43, 44, 59, 67, 70, 76, 151, 170, 173, 174, 221, 286, 294, 312, 313, 376, 381, 401, 410, 447, 468, 476, 495, 498, 508, 515, 554, 580, 628 };

const Rule = struct {
    amount: u32,
    next: usize,
};

const Bag = [4]?Rule;

fn perfectHash(first: []const u8, second: []const u8, first_indices: []const u16, second_indices: []const u16) usize {
    const a = @as(usize, first[0]) - 'a';
    const b = @as(usize, first[1]) - 'a';
    const c = @as(usize, second[0]) - 'a';
    const d = (@as(usize, second[1]) - 'a') + @as(usize, second.len & 1);
    return @as(usize, first_indices[26 * a + b]) + 18 * @as(usize, second_indices[26 * c + d]);
}

fn nextToken(input: []const u8, index: *usize) ?[]const u8 {
    var i = index.*;
    while (i < input.len) : (i += 1) {
        switch (input[i]) {
            ' ', '\n', '\r', ',', '.' => {},
            else => break,
        }
    }
    if (i >= input.len) {
        index.* = i;
        return null;
    }
    const start = i;
    while (i < input.len) : (i += 1) {
        switch (input[i]) {
            ' ', '\n', '\r', ',', '.' => break,
            else => {},
        }
    }
    index.* = i;
    return input[start..i];
}

fn isNumber(token: []const u8) bool {
    return token.len > 0 and token[0] >= '0' and token[0] <= '9';
}

fn parseNumber(token: []const u8) u32 {
    var value: u32 = 0;
    for (token) |c| value = value * 10 + (c - '0');
    return value;
}

fn solve(input: []const u8) Result {
    var first_indices = [_]u16{0} ** 676;
    var second_indices = [_]u16{0} ** 676;
    for (FirstHash, 0..) |h, idx| first_indices[h] = @intCast(idx);
    for (SecondHash, 0..) |h, idx| second_indices[h] = @intCast(idx);

    var bags = [_]Bag{[_]?Rule{null} ** 4} ** 594;

    var i: usize = 0;
    var pending: ?[]const u8 = null;

    while (true) {
        const outer_first = pending orelse nextToken(input, &i) orelse break;
        pending = null;
        const outer_second = nextToken(input, &i) orelse break;
        _ = nextToken(input, &i) orelse break;
        _ = nextToken(input, &i) orelse break;

        const outer = perfectHash(outer_first, outer_second, &first_indices, &second_indices);

        var token = nextToken(input, &i) orelse break;
        if (std.mem.eql(u8, token, "no")) {
            _ = nextToken(input, &i);
            _ = nextToken(input, &i);
            continue;
        }

        var slot: usize = 0;
        while (true) {
            const amount = parseNumber(token);
            const inner_first = nextToken(input, &i) orelse break;
            const inner_second = nextToken(input, &i) orelse break;
            _ = nextToken(input, &i);

            const inner = perfectHash(inner_first, inner_second, &first_indices, &second_indices);
            bags[outer][slot] = Rule{ .amount = amount, .next = inner };
            slot += 1;

            token = nextToken(input, &i) orelse break;
            if (!isNumber(token)) {
                pending = token;
                break;
            }
        }
    }

    const shiny_gold = perfectHash("shiny", "gold", &first_indices, &second_indices);

    var cache1 = [_]?bool{null} ** 594;
    cache1[shiny_gold] = true;
    var cache2 = [_]?u32{null} ** 594;

    const helper1 = struct {
        fn run(key: usize, bag_list: []const Bag, cache: []?bool) bool {
            if (cache[key]) |value| return value;
            var found = false;
            for (bag_list[key]) |maybe| {
                if (maybe) |rule| {
                    if (run(rule.next, bag_list, cache)) {
                        found = true;
                        break;
                    }
                }
            }
            cache[key] = found;
            return found;
        }
    }.run;

    const helper2 = struct {
        fn run(key: usize, bag_list: []const Bag, cache: []?u32) u32 {
            if (cache[key]) |value| return value;
            var total: u32 = 1;
            for (bag_list[key]) |maybe| {
                if (maybe) |rule| {
                    total += rule.amount * run(rule.next, bag_list, cache);
                }
            }
            cache[key] = total;
            return total;
        }
    }.run;

    var part1: usize = 0;
    var idx: usize = 0;
    while (idx < bags.len) : (idx += 1) {
        if (idx == shiny_gold) continue;
        if (helper1(idx, &bags, &cache1)) part1 += 1;
    }

    const part2: usize = helper2(shiny_gold, &bags, &cache2) - 1;

    return .{ .p1 = part1, .p2 = part2 };
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
