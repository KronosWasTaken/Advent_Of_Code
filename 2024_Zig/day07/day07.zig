const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

inline fn nextPow10(n: u64) u64 {
    return if (n < 10) 10 else if (n < 100) 100 else 1000;
}

fn valid(terms: []const u64, test_value: u64, index: usize, concat: bool) bool {
    if (index == 1) return test_value == terms[1];
    const term = terms[index];
    if (concat) {
        const pow10 = nextPow10(term);
        if (test_value % pow10 == term and valid(terms, test_value / pow10, index - 1, concat)) return true;
    }
    if (term != 0 and test_value % term == 0 and valid(terms, test_value / term, index - 1, concat)) return true;
    if (test_value >= term and valid(terms, test_value - term, index - 1, concat)) return true;
    return false;
}

fn solve(input: []const u8) Result {
    var p1: u64 = 0;
    var p2: u64 = 0;
    var i: usize = 0;
    var terms: [16]u64 = undefined;

    while (i < input.len) {
        var goal: u64 = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            goal = goal * 10 + @as(u64, input[i] - '0');
        }
        while (i < input.len and input[i] != ':') : (i += 1) {}
        if (i >= input.len) break;
        i += 1;

        terms[0] = goal;
        var len: usize = 1;
        while (i < input.len and input[i] != '\n') {
            if (input[i] == '\r' or input[i] == ' ') {
                i += 1;
                continue;
            }
            var n: u64 = 0;
            while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
                n = n * 10 + @as(u64, input[i] - '0');
            }
            terms[len] = n;
            len += 1;
        }
        if (i < input.len and input[i] == '\n') i += 1;
        if (len <= 1) continue;

        if (valid(terms[0..len], goal, len - 1, false)) {
            p1 += goal;
            p2 += goal;
        } else if (valid(terms[0..len], goal, len - 1, true)) {
            p2 += goal;
        }
    }

    return Result{ .p1 = p1, .p2 = p2 };
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
