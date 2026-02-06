const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

const Rule = struct {
    from: usize,
    to_left: usize,
    to_right: usize,
    element: usize,
};

fn element(byte: u8) usize {
    return @as(usize, byte - 'A');
}

fn pair(a: u8, b: u8) usize {
    return 26 * element(a) + element(b);
}

fn solve(input: []const u8) Result {
    var elements: [26]u64 = [_]u64{0} ** 26;
    var pairs: [26 * 26]u64 = [_]u64{0} ** (26 * 26);
    var rules: [100]Rule = undefined;
    var rules_len: usize = 0;

    var i: usize = 0;
    while (i < input.len and input[i] != '\n' and input[i] != '\r') : (i += 1) {}
    const template = input[0..i];
    for (template) |c| elements[element(c)] += 1;
    if (template.len >= 2) {
        var j: usize = 0;
        while (j + 1 < template.len) : (j += 1) {
            pairs[pair(template[j], template[j + 1])] += 1;
        }
    }

    while (i < input.len and (input[i] == '\r' or input[i] == '\n')) : (i += 1) {}

    var rule_bytes: [300]u8 = undefined;
    var rb_len: usize = 0;
    while (i < input.len) : (i += 1) {
        const c = input[i];
        if (c >= 'A' and c <= 'Z') {
            rule_bytes[rb_len] = c;
            rb_len += 1;
        }
    }

    var r: usize = 0;
    while (r + 2 < rb_len) : (r += 3) {
        const a = rule_bytes[r];
        const b = rule_bytes[r + 1];
        const c = rule_bytes[r + 2];
        rules[rules_len] = .{ .from = pair(a, b), .to_left = pair(a, c), .to_right = pair(c, b), .element = element(c) };
        rules_len += 1;
    }

    const step = struct {
        fn run(elements_ptr: *[26]u64, pairs_ptr: *[26 * 26]u64, rules_ptr: []const Rule, rounds: usize) void {
            var round: usize = 0;
            while (round < rounds) : (round += 1) {
                var next: [26 * 26]u64 = [_]u64{0} ** (26 * 26);
                var r_idx: usize = 0;
                while (r_idx < rules_ptr.len) : (r_idx += 1) {
                    const rule = rules_ptr[r_idx];
                    const n = pairs_ptr.*[rule.from];
                    if (n == 0) continue;
                    next[rule.to_left] += n;
                    next[rule.to_right] += n;
                    elements_ptr.*[rule.element] += n;
                }
                pairs_ptr.* = next;
            }
        }
    }.run;

    var elements1 = elements;
    var pairs1 = pairs;
    step(&elements1, &pairs1, rules[0..rules_len], 10);
    var max1: u64 = 0;
    var min1: u64 = std.math.maxInt(u64);
    for (elements1) |n| {
        if (n == 0) continue;
        if (n > max1) max1 = n;
        if (n < min1) min1 = n;
    }
    const p1 = max1 - min1;

    step(&elements, &pairs, rules[0..rules_len], 40);
    var max2: u64 = 0;
    var min2: u64 = std.math.maxInt(u64);
    for (elements) |n| {
        if (n == 0) continue;
        if (n > max2) max2 = n;
        if (n < min2) min2 = n;
    }
    const p2 = max2 - min2;

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
