const std = @import("std");

const Result = struct { p1: u32, p2: u64 };

const Rule = struct {
    start: u32,
    end: u32,
    category: u8,
    next: []const u8,
};

const Input = struct {
    workflows: std.StringHashMapUnmanaged([]Rule),
    parts: []const u8,
};

fn parseInput(alloc: std.mem.Allocator, input: []const u8) !Input {
    var clean = std.ArrayListUnmanaged(u8){};
    clean.ensureTotalCapacity(alloc, input.len) catch return error.OutOfMemory;
    for (input) |b| if (b != '\r') clean.appendAssumeCapacity(b);

    const split = std.mem.indexOf(u8, clean.items, "\n\n") orelse return Input{ .workflows = .{}, .parts = "" };
    const prefix = clean.items[0..split];
    const parts = clean.items[split + 2 ..];

    var workflows = std.StringHashMapUnmanaged([]Rule){};
    var lines = std.mem.splitScalar(u8, prefix, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");
        if (line.len == 0) continue;
        var rules = std.ArrayListUnmanaged(Rule){};
        var iter = std.mem.splitAny(u8, line, "{,:}");
        const key = iter.next().?;
        while (true) {
            const first = iter.next() orelse break;
            const second = iter.next() orelse break;
            var rule: Rule = undefined;
            if (second.len == 0) {
                rule = .{ .start = 1, .end = 4001, .category = 0, .next = first };
            } else {
                const category: u8 = switch (first[0]) {
                    'x' => 0,
                    'm' => 1,
                    'a' => 2,
                    's' => 3,
                    else => 0,
                };
                var value: u32 = 0;
                var idx: usize = 2;
                while (idx < first.len) : (idx += 1) value = value * 10 + @as(u32, first[idx] - '0');
                rule = switch (first[1]) {
                    '<' => .{ .start = 1, .end = value, .category = category, .next = second },
                    '>' => .{ .start = value + 1, .end = 4001, .category = category, .next = second },
                    else => .{ .start = 1, .end = 4001, .category = category, .next = second },
                };
            }
            rules.append(alloc, rule) catch return error.OutOfMemory;
        }
        const owned = try alloc.dupe(Rule, rules.items);
        try workflows.put(alloc, key, owned);
    }

    return .{ .workflows = workflows, .parts = parts };
}

fn part1(input: Input) u32 {
    var result: u32 = 0;
    var nums: [4]u32 = undefined;
    var idx: usize = 0;
    var buf = std.mem.tokenizeAny(u8, input.parts, "\r\n,={}xmas");
    while (buf.next()) |tok| {
        var value: u32 = 0;
        for (tok) |b| value = value * 10 + @as(u32, b - '0');
        nums[idx] = value;
        idx += 1;
        if (idx == 4) {
            idx = 0;
            var key: []const u8 = "in";
            while (key.len > 1) {
                const rules = input.workflows.get(key) orelse break;
                for (rules) |rule| {
                    const v = nums[rule.category];
                    if (rule.start <= v and v < rule.end) {
                        key = rule.next;
                        break;
                    }
                }
            }
            if (std.mem.eql(u8, key, "A")) {
                result += nums[0] + nums[1] + nums[2] + nums[3];
            }
        }
    }
    return result;
}

fn part2(input: Input) u64 {
    var result: u64 = 0;
    var stack = std.ArrayListUnmanaged(struct { key: []const u8, index: usize, part: [4][2]u32 }){};
    defer stack.deinit(std.heap.page_allocator);
    stack.append(std.heap.page_allocator, .{ .key = "in", .index = 0, .part = .{ .{ 1, 4001 }, .{ 1, 4001 }, .{ 1, 4001 }, .{ 1, 4001 } } }) catch return 0;

    while (stack.items.len > 0) {
        const item = stack.pop() orelse break;
        const key = item.key;
        const index = item.index;
        const part = item.part;
        if (key.len == 1) {
            if (std.mem.eql(u8, key, "A")) {
                var prod: u64 = 1;
                for (part) |r| prod *= @as(u64, r[1] - r[0]);
                result += prod;
            }
            continue;
        }

        const rules = input.workflows.get(key) orelse continue;
        const rule = rules[index];
        const s1 = part[rule.category][0];
        const e1 = part[rule.category][1];
        const x1 = if (s1 > rule.start) s1 else rule.start;
        const x2 = if (e1 < rule.end) e1 else rule.end;

        if (x1 >= x2) {
            stack.append(std.heap.page_allocator, .{ .key = key, .index = index + 1, .part = part }) catch return 0;
        } else {
            var new_part = part;
            new_part[rule.category] = .{ x1, x2 };
            stack.append(std.heap.page_allocator, .{ .key = rule.next, .index = 0, .part = new_part }) catch return 0;

            if (s1 < x1) {
                var left_part = part;
                left_part[rule.category] = .{ s1, x1 };
                stack.append(std.heap.page_allocator, .{ .key = key, .index = index + 1, .part = left_part }) catch return 0;
            }

            if (x2 < e1) {
                var right_part = part;
                right_part[rule.category] = .{ x2, e1 };
                stack.append(std.heap.page_allocator, .{ .key = key, .index = index + 1, .part = right_part }) catch return 0;
            }
        }
    }

    return result;
}

pub fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const parsed = parseInput(arena.allocator(), input) catch return .{ .p1 = 0, .p2 = 0 };
    const p1 = part1(parsed);
    const p2 = part2(parsed);
    return .{ .p1 = p1, .p2 = p2 };
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
