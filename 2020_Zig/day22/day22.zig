const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

const Answer = usize;
const Card = u8;
const DeckCapacity = 64;

const Input = struct {
    deck1: Deck,
    deck2: Deck,
};

const Winner = union(enum) {
    player1: Deck,
    player2: Deck,
};

const Cache = std.ArrayListUnmanaged(std.AutoHashMap(u128, void));

const Deck = struct {
    sum: usize = 0,
    score: usize = 0,
    start: usize = 0,
    end: usize = 0,
    cards: [DeckCapacity]Card = [_]Card{0} ** DeckCapacity,

    fn new() Deck {
        return .{};
    }

    fn push_back(self: *Deck, card: usize) void {
        self.cards[self.end % DeckCapacity] = @intCast(card);
        self.sum += card;
        self.score += self.sum;
        self.end += 1;
    }

    fn pop_front(self: *Deck) usize {
        const card = @as(usize, self.cards[self.start % DeckCapacity]);
        self.sum -= card;
        self.score -= self.size() * card;
        self.start += 1;
        return card;
    }

    fn size(self: Deck) usize {
        return self.end - self.start;
    }

    fn non_empty(self: Deck) bool {
        return self.end > self.start;
    }

    fn max(self: Deck) Card {
        var m: Card = 0;
        var i: usize = self.start;
        while (i < self.end) : (i += 1) {
            const value = self.cards[i % DeckCapacity];
            if (value > m) m = value;
        }
        return m;
    }

    fn copy(self: Deck, amount: usize) Deck {
        var deck_copy = Deck.new();
        deck_copy.end = amount;
        var i: usize = 0;
        while (i < amount) : (i += 1) {
            const card = self.cards[(self.start + i) % DeckCapacity];
            deck_copy.cards[i] = card;
            deck_copy.sum += card;
            deck_copy.score += deck_copy.sum;
        }
        return deck_copy;
    }
};

fn parseInput(input: []const u8) !Input {
    var deck1 = Deck.new();
    var deck2 = Deck.new();
    var player: usize = 1;

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");
        if (line.len == 0) {
            player = 2;
            continue;
        }
        if (std.mem.startsWith(u8, line, "Player")) continue;

        const card = try std.fmt.parseInt(Card, line, 10);
        if (player == 1) {
            deck1.push_back(card);
        } else {
            deck2.push_back(card);
        }
    }

    return .{ .deck1 = deck1, .deck2 = deck2 };
}

fn part1(input: Input) Answer {
    var deck1 = input.deck1;
    var deck2 = input.deck2;

    while (deck1.non_empty() and deck2.non_empty()) {
        const card1 = deck1.pop_front();
        const card2 = deck2.pop_front();

        if (card1 > card2) {
            deck1.push_back(card1);
            deck1.push_back(card2);
        } else {
            deck2.push_back(card2);
            deck2.push_back(card1);
        }
    }

    return if (deck1.non_empty()) deck1.score else deck2.score;
}

fn makeKey(score1: usize, score2: usize) u128 {
    const shift: u7 = @intCast(@bitSizeOf(usize));
    return (@as(u128, score1) << shift) | @as(u128, score2);
}

fn combat(deck1: Deck, deck2: Deck, cache: *Cache, allocator: std.mem.Allocator, depth: usize) Winner {
    var my_deck = deck1;
    var your_deck = deck2;

    if (depth > 0 and my_deck.max() > your_deck.max()) {
        return .{ .player1 = my_deck };
    }

    if (cache.items.len == depth) {
        var map = std.AutoHashMap(u128, void).init(allocator);
        map.ensureTotalCapacity(1_000) catch unreachable;
        cache.append(allocator, map) catch unreachable;
    } else {
        cache.items[depth].clearRetainingCapacity();
    }

    while (my_deck.non_empty() and your_deck.non_empty()) {
        const key = makeKey(my_deck.score, your_deck.score);
        const entry = cache.items[depth].getOrPut(key) catch unreachable;
        if (entry.found_existing) {
            return .{ .player1 = my_deck };
        }
        entry.value_ptr.* = {};

        const card1 = my_deck.pop_front();
        const card2 = your_deck.pop_front();

        if (my_deck.size() < card1 or your_deck.size() < card2) {
            if (card1 > card2) {
                my_deck.push_back(card1);
                my_deck.push_back(card2);
            } else {
                your_deck.push_back(card2);
                your_deck.push_back(card1);
            }
        } else {
            const sub_winner = combat(my_deck.copy(card1), your_deck.copy(card2), cache, allocator, depth + 1);
            switch (sub_winner) {
                .player1 => {
                    my_deck.push_back(card1);
                    my_deck.push_back(card2);
                },
                .player2 => {
                    your_deck.push_back(card2);
                    your_deck.push_back(card1);
                },
            }
        }
    }

    return if (my_deck.non_empty()) .{ .player1 = my_deck } else .{ .player2 = your_deck };
}

fn part2(input: Input, allocator: std.mem.Allocator) Answer {
    var cache = Cache{};
    defer {
        for (cache.items) |*map| {
            map.deinit();
        }
        cache.deinit(allocator);
    }

    const result = combat(input.deck1, input.deck2, &cache, allocator, 0);
    return switch (result) {
        .player1 => |deck| deck.score,
        .player2 => |deck| deck.score,
    };
}

fn solve(input_data: []const u8) !Result {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = try parseInput(input_data);
    const p1 = part1(input);
    const p2 = part2(input, arena.allocator());
    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
