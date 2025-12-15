const std = @import("std");
inline fn parseNum(input: []const u8, i: *usize) i32 {
    @setRuntimeSafety(false);
    var neg = false;
    if (input[i.*] == '-') {
        neg = true;
        i.* += 1;
    }
    var num: i32 = 0;
    while (i.* < input.len and input[i.*] >= '0' and input[i.*] <= '9') : (i.* += 1) {
        num = num * 10 + input[i.*] - '0';
    }
    return if (neg) -num else num;
}
fn part1(input: []const u8) i64 {
    @setRuntimeSafety(false);
    var sum: i64 = 0;
    var i: usize = 0;
    while (i < input.len) {
        const c = input[i];
        if (c == '-' or (c >= '0' and c <= '9')) {
            sum += parseNum(input, &i);
        } else {
            i += 1;
        }
    }
    return sum;
}
inline fn skip(input: []const u8, i: *usize) void {
    i.* += 1;
    while (i.* < input.len and input[i.*] != '"') : (i.* += 1) {}
    i.* += 1;
}
fn val(input: []const u8, i: *usize) i64 {
    @setRuntimeSafety(false);
    const c = input[i.*];
    if (c == '{') return obj(input, i);
    if (c == '[') return arr(input, i);
    if (c == '"') {
        skip(input, i);
        return 0;
    }
    if (c == '-' or (c >= '0' and c <= '9')) return parseNum(input, i);
    while (i.* < input.len and input[i.*] >= 'a' and input[i.*] <= 'z') : (i.* += 1) {}
    return 0;
}
fn arr(input: []const u8, i: *usize) i64 {
    @setRuntimeSafety(false);
    i.* += 1;
    var sum: i64 = 0;
    while (i.* < input.len and input[i.*] != ']') {
        if (input[i.*] == ',') {
            i.* += 1;
        } else {
            sum += val(input, i);
        }
    }
    i.* += 1;
    return sum;
}
fn obj(input: []const u8, i: *usize) i64 {
    @setRuntimeSafety(false);
    i.* += 1;
    var sum: i64 = 0;
    var nums: [256]i32 = undefined;
    var num_count: usize = 0;
    var has_red = false;
    while (i.* < input.len and input[i.*] != '}') {
        const c = input[i.*];
        if (c == ',' or c == ':') {
            i.* += 1;
        } else if (c == '"') {
            const s = i.* + 1;
            skip(input, i);
            if (!has_red and i.* - s == 4 and input[s] == 'r' and input[s + 1] == 'e' and input[s + 2] == 'd') {
                has_red = true;
            }
        } else if (c == '{') {
            const nested = obj(input, i);
            if (!has_red) {
                nums[num_count] = @intCast(nested);
                num_count += 1;
            }
        } else if (c == '[') {
            const nested = arr(input, i);
            if (!has_red) {
                nums[num_count] = @intCast(nested);
                num_count += 1;
            }
        } else if (c == '-' or (c >= '0' and c <= '9')) {
            const n = parseNum(input, i);
            if (!has_red) {
                nums[num_count] = n;
                num_count += 1;
            }
        } else {
            while (i.* < input.len and input[i.*] >= 'a' and input[i.*] <= 'z') : (i.* += 1) {}
        }
    }
    i.* += 1;
    if (has_red) return 0;
    for (0..num_count) |idx| {
        sum += nums[idx];
    }
    return sum;
}
fn part2(input: []const u8) i64 {
    @setRuntimeSafety(false);
    var i: usize = 0;
    return val(input, &i);
}
inline fn solve(input: []const u8) struct { p1: i64, p2: i64 } {
    return .{ .p1 = part1(input), .p2 = part2(input) };
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
