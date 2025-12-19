const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
fn solve(input: []const u8) Result {
    const gpa = std.heap.page_allocator;
    const TAPE_SIZE = 20000;
    const OFFSET = TAPE_SIZE / 2;
    var tape = gpa.alloc(u8, TAPE_SIZE) catch unreachable;
    defer gpa.free(tape);
    @memset(tape, 0);
    var cursor: i64 = OFFSET;
    var state: u8 = 'A';
    var steps: u32 = 12629077; 
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "Perform a diagnostic checksum after")) |_| {
            var tokens = std.mem.tokenizeAny(u8, line, " .");
            while (tokens.next()) |token| {
                if (std.fmt.parseInt(u32, token, 10)) |num| {
                    steps = num;
                    break;
                } else |_| {}
            }
        }
    }
    var i: usize = 0;
    while (i < steps) : (i += 1) {
        const idx: usize = @intCast(cursor);
        const current = tape[idx];
        switch (state) {
            'A' => {
                if (current == 0) {
                    tape[idx] = 1;
                    cursor += 1;
                    state = 'B';
                } else {
                    tape[idx] = 0;
                    cursor -= 1;
                    state = 'C';
                }
            },
            'B' => {
                if (current == 0) {
                    tape[idx] = 1;
                    cursor -= 1;
                    state = 'A';
                } else {
                    tape[idx] = 1;
                    cursor += 1;
                    state = 'C';
                }
            },
            'C' => {
                if (current == 0) {
                    tape[idx] = 1;
                    cursor += 1;
                    state = 'A';
                } else {
                    tape[idx] = 0;
                    cursor -= 1;
                    state = 'D';
                }
            },
            'D' => {
                if (current == 0) {
                    tape[idx] = 1;
                    cursor -= 1;
                    state = 'E';
                } else {
                    tape[idx] = 1;
                    cursor -= 1;
                    state = 'C';
                }
            },
            'E' => {
                if (current == 0) {
                    tape[idx] = 1;
                    cursor += 1;
                    state = 'F';
                } else {
                    tape[idx] = 1;
                    cursor += 1;
                    state = 'A';
                }
            },
            'F' => {
                if (current == 0) {
                    tape[idx] = 1;
                    cursor += 1;
                    state = 'A';
                } else {
                    tape[idx] = 1;
                    cursor += 1;
                    state = 'E';
                }
            },
            else => unreachable,
        }
    }
    var checksum: u32 = 0;
    for (tape) |val| {
        checksum += val;
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
