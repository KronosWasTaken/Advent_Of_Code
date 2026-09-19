const std = @import("std");

const Result = struct { p1: u32, p2: u32 };

const TAPESZ: usize = 4096;
const CACHESZ: usize = 8191;

const Rule = struct {
    write: u64 = 0,
    move: i8 = 0,
    next_state: u8 = 0,
};

const Entry = struct {
    a: u64 = 0,
    b: u64 = 0,
    next_a: u64 = 0,
    next_b: u64 = 0,
    steps: u64 = 0,
    state: u8 = 0,
    next_state: u8 = 0,
    move: i8 = 0,
};

var cache: [CACHESZ]Entry = undefined;
var tape: [TAPESZ]u64 = undefined;

inline fn lookup(a: u64, b: u64, s: u8) *Entry {
    var idx: usize = (a ^ b ^ @as(u64, s)) % CACHESZ;
    while (cache[idx].move != 0 and (cache[idx].a != a or cache[idx].b != b or cache[idx].state != s)) {
        idx += 1;
        if (idx == CACHESZ) idx = 0;
    }
    return &cache[idx];
}

fn solve(input: []const u8) Result {
    @memset(&cache, std.mem.zeroes(Entry));
    @memset(&tape, 0);

    var start_state: u8 = 0;
    var steps: u64 = 0;
    var rules: [16]Rule = [_]Rule{.{}} ** 16;

    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    var current_state: u8 = 0;
    var current_val: u8 = 0;

    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "Begin in state ")) {
            start_state = line[15] - 'A';
        } else if (std.mem.indexOf(u8, line, "checksum after ")) |_| {
            var it = std.mem.tokenizeAny(u8, line, " .");
            while (it.next()) |tok| {
                if (std.fmt.parseInt(u64, tok, 10)) |num| {
                    steps = num;
                    break;
                } else |_| {}
            }
        } else if (std.mem.startsWith(u8, line, "In state ")) {
            current_state = line[9] - 'A';
        } else if (std.mem.indexOf(u8, line, "If the current value is ")) |_| {
            const colon = std.mem.indexOf(u8, line, ":") orelse continue;
            current_val = line[colon - 1] - '0';
        } else if (std.mem.indexOf(u8, line, "- Write the value ")) |_| {
            const dot = std.mem.indexOf(u8, line, ".") orelse continue;
            rules[@as(usize, current_state) * 2 + current_val].write = line[dot - 1] - '0';
        } else if (std.mem.indexOf(u8, line, "- Move one slot to the ")) |_| {
            const move_dir: i8 = if (std.mem.indexOf(u8, line, "right") != null) 1 else -1;
            rules[@as(usize, current_state) * 2 + current_val].move = move_dir;
        } else if (std.mem.indexOf(u8, line, "- Continue with state ")) |_| {
            const dot = std.mem.indexOf(u8, line, ".") orelse continue;
            rules[@as(usize, current_state) * 2 + current_val].next_state = line[dot - 1] - 'A';
        }
    }

    var t_idx: usize = TAPESZ / 2;
    var mask: u64 = 1;
    var window_idx: usize = t_idx - 1;
    var state = start_state;

    var h: ?*Entry = lookup(0, 0, state);
    h.?.steps = steps;
    h.?.state = state;

    while (steps > 0) {
        steps -= 1;
        const symbol = (tape[t_idx] & mask) != 0;
        const sym_idx: usize = if (symbol) 1 else 0;
        const m = rules[@as(usize, state) * 2 + sym_idx];

        if (m.write != 0) {
            tape[t_idx] |= mask;
        } else {
            tape[t_idx] &= ~mask;
        }

        if (m.move > 0) {
            mask <<= 1;
        } else {
            mask >>= 1;
        }

        if (mask != 0) {
            state = m.next_state;
            continue;
        }

        if (m.move > 0) {
            mask = 1;
            t_idx += 1;
        } else {
            mask = 0x8000_0000_0000_0000;
            t_idx -= 1;
        }

        if (h == null or ((t_idx -% window_idx) & 2) == 0) {
            state = m.next_state;
            continue;
        }

        if (m.move > 0) {
            state = m.next_state;
        } else {
            const old_bit: u64 = if (symbol) 1 else 0;
            tape[t_idx + 1] ^= old_bit ^ (m.write & 1);
            t_idx += 1;
            mask = 1;
            steps += 1;
        }

        h.?.next_a = tape[window_idx];
        h.?.next_b = tape[window_idx + 1];
        h.?.next_state = state;
        h.?.steps -= steps;
        h.?.move = m.move;

        while (h != null) {
            window_idx = t_idx - 1;
            h = lookup(tape[window_idx], tape[window_idx + 1], state);
            if (h.?.move == 0) {
                h.?.a = tape[window_idx];
                h.?.b = tape[window_idx + 1];
                h.?.state = state;
                h.?.steps = steps;
                break;
            } else if (h.?.steps > steps) {
                h = null;
                break;
            } else {
                tape[window_idx] = h.?.next_a;
                tape[window_idx + 1] = h.?.next_b;
                state = h.?.next_state;
                steps -= h.?.steps;
                if (h.?.move > 0) {
                    t_idx += 1;
                } else {
                    t_idx -= 1;
                }
            }
        }
    }

    var checksum: u32 = 0;
    for (tape) |word| {
        checksum += @popCount(word);
    }

    return .{ .p1 = checksum, .p2 = 0 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
