const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

const Rule = union(enum) {
    literal: u8,
    follow: u16,
    choice: [2]u16,
    sequence: [2]u16,
    compound: [4]u16,
};

const Word = struct {
    mask: u64,
    len: u8,

    fn combined(a: Word, b: Word) ?Word {
        const total_len: u8 = a.len + b.len;
        if (total_len > 63) return null;
        const shift: u6 = @intCast(a.len);
        return Word{ .mask = (b.mask << shift) | a.mask, .len = total_len };
    }
};

fn buildWords(
    rule: u16,
    rules: *const [640]Rule,
    memo: *[640]std.ArrayListUnmanaged(Word),
    built: *[640]bool,
    allocator: std.mem.Allocator,
) ![]const Word {
    if (built[rule]) return memo[rule].items;
    built[rule] = true;

    switch (rules[rule]) {
        .literal => |c| {
            const bit: u64 = if (c == 'b') 1 else 0;
            try memo[rule].append(allocator, Word{ .mask = bit, .len = 1 });
        },
        .follow => |a| {
            const words = try buildWords(a, rules, memo, built, allocator);
            try memo[rule].appendSlice(allocator, words);
        },
        .choice => |pair| {
            const words_a = try buildWords(pair[0], rules, memo, built, allocator);
            const words_b = try buildWords(pair[1], rules, memo, built, allocator);
            try memo[rule].appendSlice(allocator, words_a);
            try memo[rule].appendSlice(allocator, words_b);
        },
        .sequence => |pair| {
            const words_a = try buildWords(pair[0], rules, memo, built, allocator);
            const words_b = try buildWords(pair[1], rules, memo, built, allocator);
            for (words_a) |a_word| {
                for (words_b) |b_word| {
                    if (Word.combined(a_word, b_word)) |combined| {
                        try memo[rule].append(allocator, combined);
                    }
                }
            }
        },
        .compound => |quad| {
            const words_a = try buildWords(quad[0], rules, memo, built, allocator);
            const words_b = try buildWords(quad[1], rules, memo, built, allocator);
            const words_c = try buildWords(quad[2], rules, memo, built, allocator);
            const words_d = try buildWords(quad[3], rules, memo, built, allocator);
            for (words_a) |a_word| {
                for (words_b) |b_word| {
                    if (Word.combined(a_word, b_word)) |combined_ab| {
                        try memo[rule].append(allocator, combined_ab);
                    }
                }
            }
            for (words_c) |c_word| {
                for (words_d) |d_word| {
                    if (Word.combined(c_word, d_word)) |combined_cd| {
                        try memo[rule].append(allocator, combined_cd);
                    }
                }
            }
        },
    }

    return memo[rule].items;
}

fn maskFromSlice(chunk: []const u8) u64 {
    var mask: u64 = 0;
    for (chunk, 0..) |char, idx| {
        if (char == 'b') {
            mask |= (@as(u64, 1) << @intCast(idx));
        }
    }
    return mask;
}

fn parseRules(input: []const u8, rules: *[640]Rule, messages_start: *usize) void {
    var idx: usize = 0;
    while (idx < input.len) {
        const line_start = idx;
        while (idx < input.len and input[idx] != '\n') idx += 1;
        var line = input[line_start..idx];
        if (line.len > 0 and line[line.len - 1] == '\r') line = line[0 .. line.len - 1];
        idx += 1;
        if (line.len == 0) break;

        var pos: usize = 0;
        const rule_id = parseNumber(line, &pos);
        pos += 2;
        if (line[pos] == '"') {
            rules[rule_id] = Rule{ .literal = line[pos + 1] };
            continue;
        }
        var nums: [4]u16 = undefined;
        var count: usize = 0;
        var has_pipe = false;
        while (pos < line.len) {
            if (line[pos] == ' ') {
                pos += 1;
                continue;
            }
            if (line[pos] == '|') {
                has_pipe = true;
                pos += 1;
                continue;
            }
            nums[count] = parseNumber(line, &pos);
            count += 1;
        }
        rules[rule_id] = switch (count) {
            1 => Rule{ .follow = nums[0] },
            2 => if (has_pipe) Rule{ .choice = .{ nums[0], nums[1] } } else Rule{ .sequence = .{ nums[0], nums[1] } },
            4 => Rule{ .compound = .{ nums[0], nums[1], nums[2], nums[3] } },
            else => unreachable,
        };
    }
    messages_start.* = idx;
}

fn parseNumber(line: []const u8, pos: *usize) u16 {
    var n: u16 = 0;
    while (pos.* < line.len and line[pos.*] >= '0' and line[pos.*] <= '9') : (pos.* += 1) {
        n = n * 10 + @as(u16, line[pos.*] - '0');
    }
    return n;
}

fn check(rules: *const [640]Rule, rule: u16, message: []const u8, index: usize) ?usize {
    const apply = struct {
        fn f(rule_set: *const [640]Rule, target_rule: u16, message_data: []const u8, start_index: usize) ?usize {
            return check(rule_set, target_rule, message_data, start_index);
        }
    }.f;
    const sequence = struct {
        fn f(rule_set: *const [640]Rule, a: u16, b: u16, message_data: []const u8, start_index: usize) ?usize {
            if (apply(rule_set, a, message_data, start_index)) |next| {
                return check(rule_set, b, message_data, next);
            }
            return null;
        }
    }.f;

    return switch (rules[rule]) {
        .literal => |c| if (index < message.len and message[index] == c) index + 1 else null,
        .follow => |a| apply(rules, a, message, index),
        .choice => |pair| apply(rules, pair[0], message, index) orelse apply(rules, pair[1], message, index),
        .sequence => |pair| sequence(rules, pair[0], pair[1], message, index),
        .compound => |quad| sequence(rules, quad[0], quad[1], message, index) orelse sequence(rules, quad[2], quad[3], message, index),
    };
}

fn solve(input: []const u8) Result {
    var rules: [640]Rule = undefined;
    var messages_start: usize = 0;
    parseRules(input, &rules, &messages_start);

    var part1: usize = 0;
    var part2: usize = 0;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }

    var memo: [640]std.ArrayListUnmanaged(Word) = undefined;
    var built: [640]bool = undefined;
    for (&memo) |*list| list.* = .{};
    for (&built) |*flag| flag.* = false;
    defer {
        for (&memo) |*list| list.deinit(allocator);
    }

    const words_42 = buildWords(42, &rules, &memo, &built, allocator) catch null;
    const words_31 = buildWords(31, &rules, &memo, &built, allocator) catch null;

    var use_optimized = false;
    var use_complement = false;
    var mask_42: [1 << 16]bool = [_]bool{false} ** (1 << 16);
    var mask_31: [1 << 16]bool = [_]bool{false} ** (1 << 16);
    var chunk_len: usize = 0;

    if (words_42) |w42| {
        if (w42.len > 0) {
            chunk_len = w42[0].len;
            use_optimized = true;
            for (w42) |word| {
                if (word.len != chunk_len or word.len > 16) {
                    use_optimized = false;
                    break;
                }
                mask_42[word.mask] = true;
            }
        }
    }

    if (use_optimized) {
        if (words_31) |w31| {
            for (w31) |word| {
                if (word.len != chunk_len or word.len > 16) {
                    use_optimized = false;
                    break;
                }
                mask_31[word.mask] = true;
            }
            if (use_optimized) {
                use_complement = true;
                var i: usize = 0;
                while (i < mask_31.len) : (i += 1) {
                    if (mask_31[i] == mask_42[i]) {
                        use_complement = false;
                        break;
                    }
                }
            }
        } else {
            use_optimized = false;
        }
    }

    var idx = messages_start;
    while (idx < input.len) {
        const line_start = idx;
        while (idx < input.len and input[idx] != '\n') idx += 1;
        var message = input[line_start..idx];
        if (message.len > 0 and message[message.len - 1] == '\r') message = message[0 .. message.len - 1];
        idx += 1;
        if (message.len == 0) continue;

        if (check(&rules, 0, message, 0) == message.len) part1 += 1;

        if (use_optimized) {
            const msg_len = message.len;
            if (msg_len % chunk_len == 0) {
                var index: usize = 0;
                var first: usize = 0;
                var second: usize = 0;
                while (index + chunk_len <= msg_len and mask_42[maskFromSlice(message[index .. index + chunk_len])]) {
                    index += chunk_len;
                    first += 1;
                }
                if (use_complement) {
                    while (index + chunk_len <= msg_len and !mask_42[maskFromSlice(message[index .. index + chunk_len])]) {
                        index += chunk_len;
                        second += 1;
                    }
                } else {
                    while (index + chunk_len <= msg_len and mask_31[maskFromSlice(message[index .. index + chunk_len])]) {
                        index += chunk_len;
                        second += 1;
                    }
                }
                if (index == msg_len and second >= 1 and first > second) part2 += 1;
            }
        } else {
            var index: usize = 0;
            var first: usize = 0;
            var second: usize = 0;
            while (check(&rules, 42, message, index)) |next| {
                index = next;
                first += 1;
            }
            if (first >= 2) {
                while (check(&rules, 31, message, index)) |next| {
                    index = next;
                    second += 1;
                }
            }
            if (index == message.len and second >= 1 and first > second) part2 += 1;
        }
    }

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
