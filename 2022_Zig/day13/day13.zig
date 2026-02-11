const std = @import("std");

const Packet = struct {
    slice: []const u8,
    index: usize,
    extra: [64]u8,
    extra_len: usize,

    fn init(input: []const u8) Packet {
        return .{ .slice = input, .index = 0, .extra = undefined, .extra_len = 0 };
    }

    fn push(self: *Packet, value: u8) void {
        self.extra[self.extra_len] = value;
        self.extra_len += 1;
    }

    fn next(self: *Packet) u8 {
        if (self.extra_len > 0) {
            self.extra_len -= 1;
            return self.extra[self.extra_len];
        }
        const i = self.index;
        if (self.slice[i] == '1' and self.slice[i + 1] == '0') {
            self.index += 2;
            return 'A';
        }
        self.index += 1;
        return self.slice[i];
    }
};

const Result = struct {
    p1: usize,
    p2: u32,
};

fn compare(left_str: []const u8, right_str: []const u8) bool {
    var left = Packet.init(left_str);
    var right = Packet.init(right_str);

    while (true) {
        const a = left.next();
        const b = right.next();
        if (a == b) continue;
        if (a == ']') return true;
        if (b == ']') return false;
        if (a == '[') {
            right.push(']');
            right.push(b);
            continue;
        }
        if (b == '[') {
            left.push(']');
            left.push(a);
            continue;
        }
        return a < b;
    }
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    var lines = std.ArrayListUnmanaged([]const u8){};
    defer lines.deinit(allocator);

    var start: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        const b = input[i];
        var newline_len: usize = 0;
        if (b == '\r') {
            newline_len = if (i + 1 < input.len and input[i + 1] == '\n') 2 else 1;
        } else if (b == '\n') {
            newline_len = 1;
        }
        if (newline_len > 0) {
            if (i > start) {
                lines.append(allocator, input[start..i]) catch unreachable;
            }
            start = i + newline_len;
            i += newline_len;
            continue;
        }
        i += 1;
    }
    if (start < input.len) lines.append(allocator, input[start..]) catch unreachable;

    var p1: usize = 0;
    var idx: usize = 0;
    var pair_index: usize = 1;
    while (idx + 1 < lines.items.len) : (idx += 2) {
        if (compare(lines.items[idx], lines.items[idx + 1])) {
            p1 += pair_index;
        }
        pair_index += 1;
    }

    var first: u32 = 1;
    var second: u32 = 2;
    for (lines.items) |line| {
        if (compare(line, "[[2]]")) {
            first += 1;
            second += 1;
        } else if (compare(line, "[[6]]")) {
            second += 1;
        }
    }

    return .{ .p1 = p1, .p2 = first * second };
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
