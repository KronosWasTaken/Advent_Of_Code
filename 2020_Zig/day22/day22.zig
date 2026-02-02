const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

const Answer = usize;
const MAX_STACK = 1000;
const Card = u8;

const Input = struct {
    allocator: std.mem.Allocator,
    cards1: []Card,
    cards2: []Card,

    fn init(allocator: std.mem.Allocator, cards1: []Card, cards2: []Card) Input {
        return .{ .allocator = allocator, .cards1 = cards1, .cards2 = cards2 };
    }

    fn deinit(self: *Input) void {
        self.allocator.free(self.cards1);
        self.allocator.free(self.cards2);
    }
};

const Player = enum {
    one,
    two,
};

fn Game(comptime MAX: usize) type {
    return struct {
        allocator: std.mem.Allocator,
        my_deck: Deck(MAX),
        your_deck: Deck(MAX),

        const Mode = enum {
            standard,
            recursive,
        };

        const Self = @This();

        fn new(input: Input) Self {
            return .{
                .allocator = input.allocator,
                .my_deck = Deck(MAX).new(input.cards1),
                .your_deck = Deck(MAX).new(input.cards2),
            };
        }

        fn newWithDecks(allocator: std.mem.Allocator, my_deck: Deck(MAX), your_deck: Deck(MAX)) Self {
            return .{ .allocator = allocator, .my_deck = my_deck, .your_deck = your_deck };
        }

        fn state(self: Self) []u8 {
            const deck1 = self.my_deck.state(self.allocator);
            defer self.allocator.free(deck1);

            const deck2 = self.your_deck.state(self.allocator);
            defer self.allocator.free(deck2);

            var states: [2][]u8 = [_][]u8{ deck1, deck2 };
            return std.mem.join(self.allocator, "   ", &states) catch unreachable;
        }

        fn play(self: *Self, mode: Mode) Player {
            var visited = std.StringHashMap(void).init(self.allocator);
            defer {
                var iterator = visited.iterator();
                while (iterator.next()) |entry| {
                    self.allocator.free(entry.key_ptr.*);
                }
                visited.deinit();
            }

            var game_winner: Player = undefined;

            while (true) {
                if (self.my_deck.depth() == 0) {
                    game_winner = .two;
                    break;
                }
                if (self.your_deck.depth() == 0) {
                    game_winner = .one;
                    break;
                }

                if (mode == .recursive) {
                    const current = self.state();
                    if (visited.contains(current)) {
                        defer self.allocator.free(current);
                        game_winner = .one;
                        break;
                    }
                    visited.put(current, {}) catch unreachable;
                }

                const card1 = self.my_deck.draw().?;
                const card2 = self.your_deck.draw().?;

                var winner: Player = undefined;
                if (mode == .recursive and card1 <= self.my_deck.depth() and card2 <= self.your_deck.depth()) {
                    var my_deck_copy = self.my_deck.copy(card1);
                    var your_deck_copy = self.your_deck.copy(card2);

                    if (my_deck_copy.max() > your_deck_copy.max()) {
                        winner = .one;
                    } else {
                        var game = Game(MAX).newWithDecks(self.allocator, my_deck_copy, your_deck_copy);
                        winner = game.play(mode);
                    }
                } else {
                    winner = if (card1 > card2) .one else .two;
                }

                self.settleRound(winner, card1, card2);
            }

            return game_winner;
        }

        fn settleRound(self: *Self, winner: Player, card1: Card, card2: Card) void {
            if (winner == .one) {
                self.my_deck.push(card1);
                self.my_deck.push(card2);
            } else {
                self.your_deck.push(card2);
                self.your_deck.push(card1);
            }
        }

        fn score(self: Self) usize {
            const deck = if (self.my_deck.depth() == 0) self.your_deck else self.my_deck;
            return deck.score();
        }
    };
}

fn parseInput(allocator: std.mem.Allocator, input: []const u8) !Input {
    var clean = std.ArrayListUnmanaged(u8){};
    defer clean.deinit(allocator);
    for (input) |ch| {
        if (ch != '\r') try clean.append(allocator, ch);
    }

    var cards1 = std.ArrayListUnmanaged(Card){};
    errdefer cards1.deinit(allocator);

    var cards2 = std.ArrayListUnmanaged(Card){};
    errdefer cards2.deinit(allocator);

    var player = Player.one;
    var lines = std.mem.splitScalar(u8, clean.items, '\n');

    while (lines.next()) |line| {
        if (line.len == 0) {
            player = .two;
            continue;
        }
        if (std.mem.startsWith(u8, line, "Player")) {
            if (std.mem.indexOfScalar(u8, line, '2') != null) {
                player = .two;
            } else {
                player = .one;
            }
            continue;
        }
        const number = try std.fmt.parseInt(Card, line, 10);
        switch (player) {
            .one => try cards1.append(allocator, number),
            .two => try cards2.append(allocator, number),
        }
    }

    return Input.init(
        allocator,
        try cards1.toOwnedSlice(allocator),
        try cards2.toOwnedSlice(allocator),
    );
}

fn Deck(comptime MAX: usize) type {
    return struct {
        cards: [MAX]Card = undefined,
        top: usize = 0,
        bottom: usize = 0,

        const Self = @This();

        fn new(cards: []const Card) Self {
            var deck = Self{};
            deck.add(cards);
            return deck;
        }

        fn add(self: *Self, cards: []const Card) void {
            for (cards) |card| {
                self.push(card);
            }
        }

        fn copy(self: Self, up_to: Card) Self {
            const slice = self.cards[self.top .. self.top + up_to];
            return Self.new(slice);
        }

        fn max(self: Self) Card {
            var m: Card = 0;
            var i: usize = 0;
            const deck_depth = self.depth();
            while (i < deck_depth) : (i += 1) {
                const v = self.cards[self.top + i];
                if (v > m) m = v;
            }
            return m;
        }

        fn state(self: Self, allocator: std.mem.Allocator) []u8 {
            const cards = self.cards[self.top..self.bottom];
            const string: [1][]const u8 = [_][]const u8{cards};
            return std.mem.join(allocator, " ", &string) catch unreachable;
        }

        fn depth(self: Self) usize {
            return self.bottom - self.top;
        }

        fn draw(self: *Self) ?Card {
            if (self.depth() == 0) return null;
            const card = self.cards[self.top];
            self.top += 1;
            return card;
        }

        fn push(self: *Self, item: Card) void {
            self.cards[self.bottom] = item;
            self.bottom += 1;
        }

        fn score(self: Self) usize {
            var s: usize = 0;
            var k: usize = 1;
            const deck_depth = self.depth();
            while (k <= deck_depth) : (k += 1) {
                const card = self.cards[self.bottom - k];
                s += k * card;
            }
            return s;
        }
    };
}

fn part1(input: Input) Answer {
    var game = Game(MAX_STACK).new(input);
    _ = game.play(.standard);
    return game.score();
}

fn part2(input: Input) Answer {
    var game = Game(MAX_STACK * 10).new(input);
    _ = game.play(.recursive);
    return game.score();
}

fn solve(input_data: []const u8) !Result {
    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(alloc.allocator());
    defer arena.deinit();

    var input = try parseInput(arena.allocator(), input_data);
    defer input.deinit();

    const p1 = part1(input);
    const p2 = part2(input);
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
