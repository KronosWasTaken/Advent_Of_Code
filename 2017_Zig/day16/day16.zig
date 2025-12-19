const std = @import("std");
const Result = struct { p1: []const u8, p2: []const u8 };
const Dance = struct {
    position: [16]usize,
    exchange: [16]usize,
    fn init() Dance {
        var d: Dance = undefined;
        for (0..16) |i| {
            d.position[i] = i;
            d.exchange[i] = i;
        }
        return d;
    }
    fn apply(self: Dance, buf: []u8) void {
        for (self.position, 0..) |i, idx| {
            buf[idx] = @as(u8, @intCast(self.exchange[i])) + 'a';
        }
    }
    fn compose(self: Dance, other: Dance) Dance {
        var result: Dance = undefined;
        for (0..16) |i| {
            result.position[i] = other.position[self.position[i]];
            result.exchange[i] = other.exchange[self.exchange[i]];
        }
        return result;
    }
};
fn parse(input: []const u8) Dance {
    var offset: usize = 0;
    var lookup: [16]usize = undefined;
    for (0..16) |i| lookup[i] = i;
    var dance = Dance.init();
    var moves = std.mem.tokenizeScalar(u8, input, ',');
    while (moves.next()) |move| {
        switch (move[0]) {
            's' => {
                const n = std.fmt.parseInt(usize, move[1..], 10) catch continue;
                offset += 16 - n;
            },
            'x' => {
                const slash = std.mem.indexOfScalar(u8, move, '/') orelse continue;
                const a = std.fmt.parseInt(usize, move[1..slash], 10) catch continue;
                const b = std.fmt.parseInt(usize, move[slash + 1 ..], 10) catch continue;
                const pos_a = (a + offset) % 16;
                const pos_b = (b + offset) % 16;
                const tmp = dance.position[pos_a];
                dance.position[pos_a] = dance.position[pos_b];
                dance.position[pos_b] = tmp;
            },
            'p' => {
                const first = move[1] - 'a';
                const second = move[3] - 'a';
                const tmp = lookup[first];
                lookup[first] = lookup[second];
                lookup[second] = tmp;
                const tmp2 = dance.exchange[lookup[first]];
                dance.exchange[lookup[first]] = dance.exchange[lookup[second]];
                dance.exchange[lookup[second]] = tmp2;
            },
            else => {},
        }
    }
    const rotate_amount = offset % 16;
    if (rotate_amount > 0) {
        std.mem.rotate(usize, &dance.position, rotate_amount);
    }
    return dance;
}
fn solve(input: []const u8) Result {
    const gpa = std.heap.page_allocator;
    const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);
    const dance = parse(trimmed);
    const p1_buf = gpa.alloc(u8, 16) catch unreachable;
    dance.apply(p1_buf);
    var cycle_len: u64 = 1;
    var current_test = dance;
    while (true) {
        var is_identity = true;
        for (0..16) |i| {
            if (current_test.position[i] != i or current_test.exchange[i] != i) {
                is_identity = false;
                break;
            }
        }
        if (is_identity) break;
        current_test = current_test.compose(dance);
        cycle_len += 1;
        if (cycle_len > 1000) break; 
    }
    var e: u64 = 1_000_000_000 % cycle_len;
    var current = dance;
    var result = Dance.init();
    while (e > 0) {
        if (e & 1 == 1) {
            result = result.compose(current);
        }
        e >>= 1;
        current = current.compose(current);
    }
    const p2_buf = gpa.alloc(u8, 16) catch unreachable;
    result.apply(p2_buf);
    return .{ .p1 = p1_buf, .p2 = p2_buf };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {s} | Part 2: {s}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
