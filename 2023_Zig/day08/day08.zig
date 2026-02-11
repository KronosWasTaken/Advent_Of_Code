const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

const Node = struct {
    left: u16,
    right: u16,
    present: bool,
};

fn encode(name: []const u8) u16 {
    const a: u16 = @intCast(name[0] - 'A');
    const b: u16 = @intCast(name[1] - 'A');
    const c: u16 = @intCast(name[2] - 'A');
    return a * 26 * 26 + b * 26 + c;
}

fn gcd(a: u64, b: u64) u64 {
    var x = a;
    var y = b;
    while (y != 0) {
        const t = x % y;
        x = y;
        y = t;
    }
    return x;
}

fn lcm(a: u64, b: u64) u64 {
    return a / gcd(a, b) * b;
}

pub fn solve(input: []const u8) Result {
    var nodes: [26 * 26 * 26]Node = undefined;
    for (&nodes) |*node| node.* = .{ .left = 0, .right = 0, .present = false };

    var lines = std.mem.splitScalar(u8, input, '\n');
    const dir_line = std.mem.trimRight(u8, lines.next() orelse "", "\r");
    _ = lines.next();

    while (lines.next()) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");
        if (line.len < 15) continue;
        const name = encode(line[0..3]);
        const left = encode(line[7..10]);
        const right = encode(line[12..15]);
        nodes[name] = .{ .left = left, .right = right, .present = true };
    }

    var starts: [26 * 26 * 26]u16 = undefined;
    var start_len: usize = 0;
    for (nodes, 0..) |node, idx| {
        if (node.present and idx % 26 == 0) {
            starts[start_len] = @intCast(idx);
            start_len += 1;
        }
    }

    var seen: [26 * 26 * 26]bool = [_]bool{false} ** (26 * 26 * 26);
    var queue_nodes: [26 * 26 * 26]u16 = undefined;
    var queue_costs: [26 * 26 * 26]u32 = undefined;

    var part_one: u64 = @intCast(dir_line.len);
    var part_two: u64 = @intCast(dir_line.len);
    const aaa = encode("AAA");

    var s: usize = 0;
    while (s < start_len) : (s += 1) {
        const start = starts[s];
        @memset(&seen, false);
        var head: usize = 0;
        var tail: usize = 0;
        queue_nodes[tail] = start;
        queue_costs[tail] = 0;
        tail += 1;
        seen[start] = true;

        while (head < tail) : (head += 1) {
            const node = queue_nodes[head];
            const cost = queue_costs[head];
            if (node % 26 == 25) {
                const c = @as(u64, cost);
                if (start == aaa) part_one = lcm(part_one, c);
                part_two = lcm(part_two, c);
                break;
            }
            const entry = nodes[node];
            const left = entry.left;
            const right = entry.right;
            if (nodes[left].present and !seen[left]) {
                seen[left] = true;
                queue_nodes[tail] = left;
                queue_costs[tail] = cost + 1;
                tail += 1;
            }
            if (nodes[right].present and !seen[right]) {
                seen[right] = true;
                queue_nodes[tail] = right;
                queue_costs[tail] = cost + 1;
                tail += 1;
            }
        }
    }

    return .{ .p1 = part_one, .p2 = part_two };
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
