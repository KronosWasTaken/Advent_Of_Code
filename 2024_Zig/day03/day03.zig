const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

fn parseNumber(memory: []const u8, index: *usize) u32 {
    var number: u32 = 0;
    while (index.* < memory.len) {
        const byte = memory[index.*];
        if (byte < '0' or byte > '9') break;
        number = number * 10 + (byte - '0');
        index.* += 1;
    }
    return number;
}

fn solve(input: []const u8) Result {
    var index: usize = 0;
    var enabled = true;
    var part_one: u32 = 0;
    var part_two: u32 = 0;

    while (index < input.len) {
        const next = std.mem.indexOfAnyPos(u8, input, index, "md") orelse break;
        index = next;

        if (std.mem.startsWith(u8, input[index..], "mul(")) {
            index += 4;
        } else if (std.mem.startsWith(u8, input[index..], "do()")) {
            index += 4;
            enabled = true;
            continue;
        } else if (std.mem.startsWith(u8, input[index..], "don't()")) {
            index += 7;
            enabled = false;
            continue;
        } else {
            index += 1;
            continue;
        }

        const first = parseNumber(input, &index);
        if (index >= input.len or input[index] != ',') {
            continue;
        }
        index += 1;

        const second = parseNumber(input, &index);
        if (index >= input.len or input[index] != ')') {
            continue;
        }
        index += 1;

        const product = first * second;
        part_one += product;
        if (enabled) {
            part_two += product;
        }
    }

    return Result{ .p1 = part_one, .p2 = part_two };
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
