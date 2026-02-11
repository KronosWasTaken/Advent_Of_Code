const std = @import("std");

const Result = struct {
    p1: i64,
    p2: i64,
};

fn foldDecimal(slice: []i32) i32 {
    var acc: i32 = 0;
    for (slice) |b| {
        acc = 10 * acc + b;
    }
    return acc;
}

fn gcd(a: usize, b: usize) usize {
    var x = a;
    var y = b;
    while (y != 0) {
        const temp = y;
        y = x % y;
        x = temp;
    }
    return x;
}

fn lcm(a: usize, b: usize) usize {
    return a / gcd(a, b) * b;
}

fn part1(input: []i32, allocator: std.mem.Allocator) !i32 {
    const size = input.len;
    const limit = size / 3;

    var digits = try allocator.dupe(i32, input);
    defer allocator.free(digits);

    var prefix_sum = try allocator.alloc(i32, size + 1);
    defer allocator.free(prefix_sum);

    for (0..100) |_| {

        var sum: i32 = 0;
        prefix_sum[0] = 0;
        for (digits, 0..) |digit, i| {
            sum += digit;
            prefix_sum[i + 1] = sum;
        }


        for (0..limit) |i| {
            const phase: i32 = @intCast(i + 1);
            var total: i32 = 0;
            var sign: i32 = 1;

            var start = @as(i32, @intCast(phase - 1));
            while (start < @as(i32, @intCast(size))) : (start += 2 * phase) {
                const end = @min(start + phase, @as(i32, @intCast(size)));
                total += sign * (prefix_sum[@intCast(end)] - prefix_sum[@intCast(start)]);
                sign *= -1;
            }

            digits[i] = @as(i32, @intCast(@mod(@abs(total), 10)));
        }


        for (limit..size) |i| {
            const phase: i32 = @intCast(i + 1);
            const start: i32 = phase - 1;
            const end = @min(start + phase, @as(i32, @intCast(size)));
            const diff = prefix_sum[@intCast(end)] - prefix_sum[@intCast(start)];
            digits[i] = @as(i32, @intCast(@mod(@abs(diff), 10)));
        }
    }

    return foldDecimal(digits[0..8]);
}

fn part2(input: []i32, _: std.mem.Allocator) !i32 {
    const size = input.len;
    const lower = size * 5_000;
    const upper = size * 10_000;


    var start: usize = 0;
    for (input[0..7]) |digit| {
        start = start * 10 + @as(usize, @intCast(digit));
    }


    if (start < lower or start >= upper) {
        return 0;
    }


    const BINOMIAL_MOD_2 = [_][2]i32{
        .{ 1, 4 }, .{ 1, 4 }, .{ 1, 4 }, .{ 1, 4 },
        .{ 1, 4 }, .{ 1, 4 }, .{ 1, 4 }, .{ 1, 100 },
    };

    const BINOMIAL_MOD_5 = [_][2]i32{
        .{ 1, 25 }, .{ 4, 100 },
    };

    var result_mod2: [8]i32 = undefined;
    var result_mod5: [8]i32 = undefined;

    for (0..8) |offset| {
        const start_pos = start + offset;
        const total = upper - start_pos;


        const lcm2 = lcm(size, 128);
        const quotient2 = @as(i32, @intCast(total / lcm2));
        const remainder2 = total % lcm2;

        var index = start_pos;
        var partial2: i32 = 0;
        var coeff_idx2: usize = 0;


        while (index < start_pos + remainder2) {
            const coeff_pair = BINOMIAL_MOD_2[coeff_idx2 % BINOMIAL_MOD_2.len];
            const coefficient = coeff_pair[0];
            const skip = @as(usize, @intCast(coeff_pair[1]));

            partial2 += input[index % size] * coefficient;
            index += skip;
            coeff_idx2 += 1;
        }

        var full2 = partial2;
        while (index < start_pos + lcm2) {
            const coeff_pair = BINOMIAL_MOD_2[coeff_idx2 % BINOMIAL_MOD_2.len];
            const coefficient = coeff_pair[0];
            const skip = @as(usize, @intCast(coeff_pair[1]));

            full2 += input[index % size] * coefficient;
            index += skip;
            coeff_idx2 += 1;
        }

        result_mod2[offset] = @as(i32, @mod(quotient2 * full2 + partial2, 2));


        const lcm5 = lcm(size, 125);
        const quotient5 = @as(i32, @intCast(total / lcm5));
        const remainder5 = total % lcm5;

        index = start_pos;
        var partial5: i32 = 0;
        var coeff_idx5: usize = 0;

        while (index < start_pos + remainder5) {
            const coeff_pair = BINOMIAL_MOD_5[coeff_idx5 % BINOMIAL_MOD_5.len];
            const coefficient = coeff_pair[0];
            const skip = @as(usize, @intCast(coeff_pair[1]));

            partial5 += input[index % size] * coefficient;
            index += skip;
            coeff_idx5 += 1;
        }

        var full5 = partial5;
        while (index < start_pos + lcm5) {
            const coeff_pair = BINOMIAL_MOD_5[coeff_idx5 % BINOMIAL_MOD_5.len];
            const coefficient = coeff_pair[0];
            const skip = @as(usize, @intCast(coeff_pair[1]));

            full5 += input[index % size] * coefficient;
            index += skip;
            coeff_idx5 += 1;
        }

        result_mod5[offset] = @as(i32, @mod(quotient5 * full5 + partial5, 5));
    }


    var result: [8]i32 = undefined;
    for (0..8) |i| {
        result[i] = @mod(5 * result_mod2[i] + 6 * result_mod5[i], 10);
    }

    return foldDecimal(&result);
}

fn parse(input: []const u8, allocator: std.mem.Allocator) ![]i32 {
    var digits = try std.ArrayList(i32).initCapacity(allocator, 300);

    for (input) |c| {
        if (c >= '0' and c <= '9') {
            try digits.append(allocator, @as(i32, c - '0'));
        }
    }

    return digits.toOwnedSlice(allocator);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input_str = @embedFile("input.txt");
    const digits = try parse(input_str, allocator);
    defer allocator.free(digits);

    var timer = try std.time.Timer.start();
    const start_time = timer.read();

    const p1 = try part1(digits, allocator);
    const p2 = try part2(digits, allocator);

    const elapsed_ns = timer.read() - start_time;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;

    std.debug.print("Part 1: {}\n", .{p1});
    std.debug.print("Part 2: {}\n", .{p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
