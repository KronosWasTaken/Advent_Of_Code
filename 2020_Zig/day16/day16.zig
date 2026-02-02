const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u64,
};

const Range = struct {
    min: u32,
    max: u32,

    fn validFor(self: Range, number: u32) bool {
        return number >= self.min and number <= self.max;
    }
};

const Rule = struct {
    is_departure: bool,
    left: Range,
    right: Range,

    fn validFor(self: Rule, number: u32) bool {
        return self.left.validFor(number) or self.right.validFor(number);
    }
};

const Ticket = struct {
    numbers: []u32,
    valid: bool,
};

fn parseRule(line: []const u8) Rule {
    var parts = std.mem.splitSequence(u8, line, ": ");
    const name = parts.next().?;
    const is_departure = std.mem.startsWith(u8, name, "departure");
    const rule_str = parts.next().?;

    var rule_split = std.mem.splitSequence(u8, rule_str, " or ");
    const left_str = rule_split.next().?;
    const right_str = rule_split.next().?;

    var left_split = std.mem.splitSequence(u8, left_str, "-");
    const left_min = std.fmt.parseInt(u32, left_split.next().?, 10) catch unreachable;
    const left_max = std.fmt.parseInt(u32, left_split.next().?, 10) catch unreachable;

    var right_split = std.mem.splitSequence(u8, right_str, "-");
    const right_min = std.fmt.parseInt(u32, right_split.next().?, 10) catch unreachable;
    const right_max = std.fmt.parseInt(u32, right_split.next().?, 10) catch unreachable;

    return .{ .is_departure = is_departure, .left = .{ .min = left_min, .max = left_max }, .right = .{ .min = right_min, .max = right_max } };
}

fn parseTicket(allocator: std.mem.Allocator, line: []const u8) Ticket {
    var list = std.ArrayListUnmanaged(u32){};
    errdefer list.deinit(allocator);
    var numbers = std.mem.splitSequence(u8, line, ",");
    while (numbers.next()) |token| {
        list.append(allocator, std.fmt.parseInt(u32, token, 10) catch unreachable) catch unreachable;
    }
    return .{ .numbers = list.toOwnedSlice(allocator) catch unreachable, .valid = true };
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const Stage = enum { rules, your_ticket, nearby };
    var stage = Stage.rules;

    var rules = std.ArrayListUnmanaged(Rule){};
    errdefer rules.deinit(arena.allocator());

    var your: Ticket = .{ .numbers = &[_]u32{}, .valid = true };
    var nearby = std.ArrayListUnmanaged(Ticket){};
    errdefer nearby.deinit(arena.allocator());

    var line_start: usize = 0;
    var i: usize = 0;
    while (i <= input.len) : (i += 1) {
        if (i == input.len or input[i] == '\n') {
            var line = input[line_start..i];
            if (line.len > 0 and line[line.len - 1] == '\r') {
                line = line[0 .. line.len - 1];
            }
            line_start = i + 1;
            if (line.len == 0) continue;

            switch (stage) {
                .rules => {
                    if (std.mem.startsWith(u8, line, "your")) {
                        stage = .your_ticket;
                        continue;
                    }
                    rules.append(arena.allocator(), parseRule(line)) catch unreachable;
                },
                .your_ticket => {
                    if (std.mem.startsWith(u8, line, "nearby")) {
                        stage = .nearby;
                        continue;
                    }
                    your = parseTicket(arena.allocator(), line);
                },
                .nearby => {
                    nearby.append(arena.allocator(), parseTicket(arena.allocator(), line)) catch unreachable;
                },
            }
        }
    }

    const field_count = rules.items.len;

    var error_rate: u32 = 0;
    for (nearby.items) |*ticket| {
        for (ticket.numbers) |value| {
            var ok = false;
            for (rules.items) |rule| {
                if (rule.validFor(value)) {
                    ok = true;
                    break;
                }
            }
            if (!ok) {
                error_rate += value;
                ticket.valid = false;
            }
        }
    }

    var possible = arena.allocator().alloc(u32, field_count) catch unreachable;
    var col: usize = 0;
    while (col < field_count) : (col += 1) {
        possible[col] = if (field_count == 32) 0xffffffff else (@as(u32, 1) << @intCast(field_count)) - 1;
    }

    for (nearby.items) |ticket| {
        if (!ticket.valid) continue;
        var c: usize = 0;
        while (c < field_count) : (c += 1) {
            const value = ticket.numbers[c];
            var mask: u32 = 0;
            var r: usize = 0;
            while (r < rules.items.len) : (r += 1) {
                if (rules.items[r].validFor(value)) mask |= @as(u32, 1) << @intCast(r);
            }
            possible[c] &= mask;
        }
    }

    var resolved = arena.allocator().alloc(u32, field_count) catch unreachable;
    @memset(resolved, 0);

    var remaining = field_count;
    while (remaining > 0) {
        var progress = false;
        col = 0;
        while (col < field_count) : (col += 1) {
            const mask = possible[col];
            if (mask != 0 and (mask & (mask - 1)) == 0) {
                const rule_idx = @ctz(mask);
                resolved[col] = @intCast(rule_idx);
                possible[col] = 0;
                remaining -= 1;
                progress = true;
                var j: usize = 0;
                while (j < field_count) : (j += 1) {
                    if (possible[j] != 0) possible[j] &= ~mask;
                }
            }
        }
        if (!progress) break;
    }

    var product: u64 = 1;
    col = 0;
    while (col < field_count) : (col += 1) {
        const rule_idx = resolved[col];
        if (rules.items[rule_idx].is_departure) {
            product *= your.numbers[col];
        }
    }

    return .{ .p1 = error_rate, .p2 = product };
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
