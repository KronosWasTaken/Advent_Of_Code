const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

const BoardSize = 25;
const Lines = [_][2]usize{
    .{ 0, 1 }, .{ 5, 1 }, .{ 10, 1 }, .{ 15, 1 }, .{ 20, 1 },
    .{ 0, 5 }, .{ 1, 5 }, .{ 2, 5 },  .{ 3, 5 },  .{ 4, 5 },
};

fn solve(input: []const u8) Result {
    var number_to_turn: [100]usize = [_]usize{0} ** 100;
    var turn_to_number: [100]usize = [_]usize{0} ** 100;

    var i: usize = 0;
    var turn: usize = 0;
    while (i + 1 < input.len) {
        if (input[i] == '\r' and input[i + 1] == '\n') {
            i += 2;
            if (i + 1 < input.len and input[i] == '\r' and input[i + 1] == '\n') {
                i += 2;
            }
            break;
        }
        if (input[i] < '0' or input[i] > '9') {
            i += 1;
            continue;
        }
        var value: usize = 0;
        while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
            value = value * 10 + @as(usize, input[i] - '0');
        }
        number_to_turn[value] = turn;
        turn_to_number[turn] = value;
        turn += 1;
    }

    var best_turn: usize = std.math.maxInt(usize);
    var best_score: usize = 0;
    var worst_turn: usize = 0;
    var worst_score: usize = 0;

    while (i < input.len) {
        if (input[i] < '0' or input[i] > '9') {
            i += 1;
            continue;
        }
        var board: [BoardSize]usize = undefined;
        var idx: usize = 0;
        while (idx < BoardSize and i < input.len) {
            if (input[i] < '0' or input[i] > '9') {
                i += 1;
                continue;
            }
            var value: usize = 0;
            while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
                value = value * 10 + @as(usize, input[i] - '0');
            }
            board[idx] = value;
            idx += 1;
        }
        if (idx < BoardSize) break;

        var turns: [BoardSize]usize = undefined;
        var t: usize = 0;
        while (t < BoardSize) : (t += 1) {
            turns[t] = number_to_turn[board[t]];
        }

        var winning_turn: usize = std.math.maxInt(usize);
        for (Lines) |line| {
            const start = line[0];
            const step = line[1];
            var max_turn: usize = 0;
            var k: usize = 0;
            while (k < 5) : (k += 1) {
                const value_turn = turns[start + k * step];
                if (value_turn > max_turn) max_turn = value_turn;
            }
            if (max_turn < winning_turn) winning_turn = max_turn;
        }

        var unmarked: usize = 0;
        var b: usize = 0;
        while (b < BoardSize) : (b += 1) {
            if (number_to_turn[board[b]] > winning_turn) unmarked += board[b];
        }
        const score = unmarked * turn_to_number[winning_turn];

        if (winning_turn < best_turn) {
            best_turn = winning_turn;
            best_score = score;
        }
        if (winning_turn > worst_turn) {
            worst_turn = winning_turn;
            worst_score = score;
        }
    }

    return .{ .p1 = best_score, .p2 = worst_score };
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
