const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

fn scoreLine(line: []const u8, stack: *[256]u8, stack_len: *usize) u64 {
    stack_len.* = 0;
    for (line) |c| {
        switch (c) {
            '(', '[', '{', '<' => {
                stack.*[stack_len.*] = c;
                stack_len.* += 1;
            },
            ')' => {
                if (stack_len.* == 0 or stack.*[stack_len.* - 1] != '(') return 3;
                stack_len.* -= 1;
            },
            ']' => {
                if (stack_len.* == 0 or stack.*[stack_len.* - 1] != '[') return 57;
                stack_len.* -= 1;
            },
            '}' => {
                if (stack_len.* == 0 or stack.*[stack_len.* - 1] != '{') return 1197;
                stack_len.* -= 1;
            },
            '>' => {
                if (stack_len.* == 0 or stack.*[stack_len.* - 1] != '<') return 25137;
                stack_len.* -= 1;
            },
            else => {},
        }
    }
    return 0;
}

fn solve(input: []const u8) Result {
    var stack: [256]u8 = undefined;
    var stack_len: usize = 0;

    const allocator = std.heap.page_allocator;
    var line_count: usize = 0;
    for (input) |c| {
        if (c == '\n') line_count += 1;
    }
    if (input.len > 0 and input[input.len - 1] != '\n') line_count += 1;

    var scores = allocator.alloc(u64, line_count) catch unreachable;
    defer allocator.free(scores);

    var p1: u64 = 0;
    var score_index: usize = 0;

    var i: usize = 0;
    while (i <= input.len) {
        const start = i;
        while (i < input.len and input[i] != '\n') : (i += 1) {}
        var end = i;
        if (end > start and input[end - 1] == '\r') end -= 1;
        const line = input[start..end];

        if (line.len > 0) {
            const corrupt = scoreLine(line, &stack, &stack_len);
            if (corrupt != 0) {
                p1 += corrupt;
            } else {
                var score: u64 = 0;
                var idx = stack_len;
                while (idx > 0) {
                    idx -= 1;
                    var v: u64 = 0;
                    switch (stack[idx]) {
                        '(' => v = 1,
                        '[' => v = 2,
                        '{' => v = 3,
                        '<' => v = 4,
                        else => v = 0,
                    }
                    score = score * 5 + v;
                }
                scores[score_index] = score;
                score_index += 1;
            }
        }

        if (i >= input.len) break;
        i += 1;
    }

    const scores_slice = scores[0..score_index];
    std.mem.sortUnstable(u64, scores_slice, {}, comptime std.sort.asc(u64));
    const p2 = scores_slice[scores_slice.len / 2];
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
