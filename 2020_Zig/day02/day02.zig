const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

fn parseNumber(input: []const u8, index: *usize) usize {
    var value: usize = 0;
    while (index.* < input.len and input[index.*] >= '0') : (index.* += 1) {
        value = value * 10 + (input[index.*] - '0');
    }
    return value;
}

fn vectorMask(chunk: [32]u8, letter: u8) u32 {
    const vec: @Vector(32, u8) = @bitCast(chunk);
    const eq = vec == @as(@Vector(32, u8), @splat(letter));
    var mask: u32 = 0;
    inline for (0..32) |idx| {
        mask |= (@as(u32, @intFromBool(eq[idx])) << @intCast(idx));
    }
    return mask;
}

fn solve(input: []const u8) Result {
    var i: usize = 0;
    var p1: usize = 0;
    var p2: usize = 0;

    while (i < input.len) {
        while (i < input.len and (input[i] == '\n' or input[i] == '\r' or input[i] == ' ')) : (i += 1) {}
        if (i >= input.len) break;

        const start = parseNumber(input, &i);
        if (i >= input.len or input[i] != '-') break;
        i += 1;
        const end = parseNumber(input, &i);
        if (i >= input.len or input[i] != ' ') break;
        i += 1;

        if (i >= input.len) break;
        const letter = input[i];
        i += 1;
        if (i + 1 >= input.len or input[i] != ':' or input[i + 1] != ' ') break;
        i += 2;

        const line_start = i;
        while (i < input.len and input[i] != '\n' and input[i] != '\r') : (i += 1) {}
        const line_len = i - line_start;

        var count: usize = 0;
        var mask: u32 = 0;

        if (line_len >= 32) {
            const ptr0 = @as(*const [32]u8, @ptrCast(input.ptr + line_start));
            mask = vectorMask(ptr0.*, letter);
            count += @popCount(mask);

            var offset: usize = 32;
            while (offset + 32 <= line_len) : (offset += 32) {
                const ptr = @as(*const [32]u8, @ptrCast(input.ptr + line_start + offset));
                count += @popCount(vectorMask(ptr.*, letter));
            }

            var tail = line_start + offset;
            while (tail < line_start + line_len) : (tail += 1) {
                count += @intFromBool(input[tail] == letter);
            }
        } else {
            var chunk: [32]u8 = [_]u8{0} ** 32;
            std.mem.copyForwards(u8, chunk[0..line_len], input[line_start .. line_start + line_len]);
            mask = vectorMask(chunk, letter) & ((@as(u32, 1) << @intCast(line_len)) - 1);
            count = @popCount(mask);
        }

        if (start <= count and count <= end) p1 += 1;

        const first = (start <= 32) and ((mask >> @intCast(start - 1)) & 1) == 1;
        const second = (end <= 32) and ((mask >> @intCast(end - 1)) & 1) == 1;
        if (first != second) p2 += 1;

        if (i < input.len and input[i] == '\r') i += 1;
        if (i < input.len and input[i] == '\n') i += 1;
    }

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
