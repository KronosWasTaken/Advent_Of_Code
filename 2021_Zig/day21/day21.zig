const std = @import("std");

const Result = struct { p1: usize, p2: usize };

const DIRAC = [_][2]usize{ .{ 3, 1 }, .{ 4, 3 }, .{ 5, 6 }, .{ 6, 7 }, .{ 7, 6 }, .{ 8, 3 }, .{ 9, 1 } };

const State = struct { p0: usize, s0: usize, p1: usize, s1: usize };

const WinLose = struct { win: usize, lose: usize };

fn parseLine(line: []const u8) usize {
    var value: usize = 0;
    var in_num = false;
    for (line) |c| {
        if (c >= '0' and c <= '9') {
            value = value * 10 + @as(usize, c - '0');
            in_num = true;
        } else if (in_num) {
            in_num = false;
        }
    }
    return value;
}

fn parse(input: []const u8) [2]usize {
    var lines = std.mem.splitScalar(u8, input, '\n');
    var result: [2]usize = undefined;
    var idx: usize = 0;
    while (lines.next()) |raw| {
        const line = std.mem.trimRight(u8, raw, "\r");
        if (line.len == 0) continue;
        result[idx] = parseLine(line) - 1;
        idx += 1;
        if (idx == 2) break;
    }
    return result;
}

fn part1(start: [2]usize) usize {
    var state = State{ .p0 = start[0], .s0 = 0, .p1 = start[1], .s1 = 0 };
    var dice: usize = 6;
    var rolls: usize = 0;
    while (true) {
        const next_pos = (state.p0 + dice) % 10;
        const next_score = state.s0 + next_pos + 1;
        dice = (dice + 9) % 10;
        rolls += 3;
        if (next_score >= 1000) return state.s1 * rolls;
        state = State{ .p0 = state.p1, .s0 = state.s1, .p1 = next_pos, .s1 = next_score };
    }
}

fn dirac(state: [4]u8, cache: []?WinLose) WinLose {
    const index = @as(usize, state[0]) + 10 * @as(usize, state[2]) + 100 * @as(usize, state[1]) + 2100 * @as(usize, state[3]);
    if (cache[index]) |v| return v;

    var win: usize = 0;
    var lose: usize = 0;
    for (DIRAC) |entry| {
        const dice = entry[0];
        const freq = entry[1];
        const next_pos = (@as(usize, state[0]) + dice) % 10;
        const next_score = @as(usize, state[1]) + next_pos + 1;
        if (next_score >= 21) {
            win += freq;
        } else {
            const next_state = [4]u8{ @as(u8, @intCast(state[2])), @as(u8, @intCast(state[3])), @as(u8, @intCast(next_pos)), @as(u8, @intCast(next_score)) };
            const result = dirac(next_state, cache);
            win += freq * result.lose;
            lose += freq * result.win;
        }
    }
    const out = WinLose{ .win = win, .lose = lose };
    cache[index] = out;
    return out;
}

fn part2(start: [2]usize) usize {
    var cache: [44100]?WinLose = [_]?WinLose{null} ** 44100;
    const state = [4]u8{ @as(u8, @intCast(start[0])), 0, @as(u8, @intCast(start[1])), 0 };
    const result = dirac(state, cache[0..]);
    return if (result.win > result.lose) result.win else result.lose;
}

fn solve(input: []const u8) Result {
    const start = parse(input);
    return .{ .p1 = part1(start), .p2 = part2(start) };
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
