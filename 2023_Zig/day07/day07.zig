const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

const Hand = struct {
    cards: [5]u8,
    bid: u64,
};

fn parseBid(line: []const u8) u64 {
    var value: u64 = 0;
    for (line) |b| {
        if (b >= '0' and b <= '9') value = value * 10 + (b - '0');
    }
    return value;
}

fn parseInput(alloc: std.mem.Allocator, input: []const u8) ![]Hand {
    var list: std.ArrayListUnmanaged(Hand) = .{};
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");
        if (line.len < 6) continue;
        var cards: [5]u8 = undefined;
        @memcpy(&cards, line[0..5]);
        const bid = parseBid(line[5..]);
        try list.append(alloc, .{ .cards = cards, .bid = bid });
    }
    return list.toOwnedSlice(alloc);
}

fn handKey(cards: [5]u8, j: u8) u64 {
    var rank: [5]u8 = undefined;
    for (cards, 0..) |b, i| {
        rank[i] = switch (b) {
            'A' => 14,
            'K' => 13,
            'Q' => 12,
            'J' => j,
            'T' => 10,
            else => b - '0',
        };
    }
    var freq: [15]u8 = [_]u8{0} ** 15;
    for (rank) |r| freq[r] += 1;
    const jokers = freq[1];
    freq[1] = 0;
    std.mem.sort(u8, freq[0..], {}, comptime std.sort.desc(u8));
    freq[0] += jokers;

    var key: u64 = 0;
    var i: usize = 0;
    while (i < 5) : (i += 1) key = (key << 4) | freq[i];
    for (rank) |r| key = (key << 4) | r;
    return key;
}

const KeyBid = struct { key: u64, bid: u64 };

fn solveWithJ(input: []const Hand, j: u8) u64 {
    var list: std.ArrayListUnmanaged(KeyBid) = .{};
    defer list.deinit(std.heap.page_allocator);
    for (input) |hand| {
        list.append(std.heap.page_allocator, .{ .key = handKey(hand.cards, j), .bid = hand.bid }) catch return 0;
    }
    std.mem.sort(KeyBid, list.items, {}, struct {
        fn lessThan(_: void, a: KeyBid, b: KeyBid) bool {
            return a.key < b.key;
        }
    }.lessThan);

    var sum: u64 = 0;
    for (list.items, 0..) |item, idx| {
        sum += @as(u64, idx + 1) * item.bid;
    }
    return sum;
}

pub fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const hands = parseInput(alloc, input) catch return .{ .p1 = 0, .p2 = 0 };
    return .{ .p1 = solveWithJ(hands, 11), .p2 = solveWithJ(hands, 1) };
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
