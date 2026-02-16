const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

const Node = struct {
    next: [6]usize,

    fn init() Node {
        return .{ .next = [_]usize{0} ** 6 };
    }

    fn setTowel(self: *Node) void {
        self.next[3] = 1;
    }

    fn towels(self: Node) usize {
        return self.next[3];
    }
};

fn perfectHash(b: u8) usize {
    const n: usize = b;
    return (n ^ (n >> 4)) % 8;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    const sep = std.mem.indexOf(u8, input, "\r\n\r\n") orelse std.mem.indexOf(u8, input, "\n\n") orelse input.len;
    const prefix = input[0..sep];
    var suffix: []const u8 = "";
    if (sep < input.len) {
        const jump: usize = if (input[sep] == '\r') 4 else 2;
        if (sep + jump <= input.len) {
            suffix = input[sep + jump ..];
        }
    }

    var trie: std.ArrayListUnmanaged(Node) = .{};
    defer trie.deinit(allocator);
    try trie.append(allocator, Node.init());

    var start: usize = 0;
    while (start < prefix.len) {
        var end = start;
        while (end < prefix.len and prefix[end] != '\n' and prefix[end] != '\r' and prefix[end] != ',') : (end += 1) {}
        if (end == start) {
            start += 1;
            continue;
        }
        var i: usize = 0;
        var j: usize = start;
        while (j < end) : (j += 1) {
            const ch = prefix[j];
            if (ch == ' ' or ch == ',') continue;
            const idx = perfectHash(ch);
            if (trie.items[i].next[idx] == 0) {
                trie.items[i].next[idx] = trie.items.len;
                i = trie.items.len;
                try trie.append(allocator, Node.init());
            } else {
                i = trie.items[i].next[idx];
            }
        }
        trie.items[i].setTowel();
        start = end + 1;
    }

    var ways: std.ArrayListUnmanaged(usize) = .{};
    defer ways.deinit(allocator);

    var part1: usize = 0;
    var part2: usize = 0;

    var line_it = std.mem.splitScalar(u8, suffix, '\n');
    while (line_it.next()) |raw| {
        var line = raw;
        if (line.len > 0 and line[line.len - 1] == '\r') line = line[0 .. line.len - 1];
        if (line.len == 0) continue;
        const size = line.len;
        ways.clearRetainingCapacity();
        try ways.resize(allocator, size + 1);
        @memset(ways.items, 0);
        ways.items[0] = 1;

        var start_idx: usize = 0;
        while (start_idx < size) : (start_idx += 1) {
            if (ways.items[start_idx] == 0) continue;
            var i: usize = 0;
            var end_idx: usize = start_idx;
            while (end_idx < size) : (end_idx += 1) {
                i = trie.items[i].next[perfectHash(line[end_idx])];
                if (i == 0) break;
                ways.items[end_idx + 1] += trie.items[i].towels() * ways.items[start_idx];
            }
        }
        const total = ways.items[size];
        if (total > 0) part1 += 1;
        part2 += total;
    }

    return .{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, std.heap.page_allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
