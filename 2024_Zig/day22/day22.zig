const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u16,
};

const mask: u32 = 0xffffff;
const ten: u32 = 10;
const nine: u32 = 9;
const mul_a: u32 = 6859;
const mul_b: u32 = 361;
const mul_c: u32 = 19;

fn nextUnsigned(input: []const u8, index: *usize) ?u32 {
    var i = index.*;
    while (i < input.len and (input[i] < '0' or input[i] > '9')) : (i += 1) {}
    if (i >= input.len) {
        index.* = i;
        return null;
    }
    var value: u32 = 0;
    while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
        value = value * 10 + @as(u32, input[i] - '0');
    }
    index.* = i;
    return value;
}

inline fn hash(n_in: u32) u32 {
    var n = n_in;
    n = (n ^ (n << 6)) & mask;
    n = (n ^ (n >> 5)) & mask;
    return (n ^ (n << 11)) & mask;
}

inline fn toIndex(previous: u32, current: u32) u32 {
    return nine + current % ten - previous % ten;
}

const Vec = @Vector(8, u32);
const mask_vec: Vec = @splat(mask);
const ten_vec: Vec = @splat(ten);
const nine_vec: Vec = @splat(nine);
const mul_a_vec: Vec = @splat(mul_a);
const mul_b_vec: Vec = @splat(mul_b);
const mul_c_vec: Vec = @splat(mul_c);

inline fn hashVec(n_in: Vec) Vec {
    var n = n_in;
    n = (n ^ (n << @splat(@as(u5, 6)))) & mask_vec;
    n = (n ^ (n >> @splat(@as(u5, 5)))) & mask_vec;
    return (n ^ (n << @splat(@as(u5, 11)))) & mask_vec;
}

inline fn toIndexVec(previous: Vec, current: Vec) Vec {
    return nine_vec + current % ten_vec - previous % ten_vec;
}

fn processScalar(start_num: u32, id: u16, seen: []u16, part_two: *[130321]u16) u32 {
    const zeroth = start_num;
    const first = hash(zeroth);
    const second = hash(first);
    const third = hash(second);

    var a: u32 = undefined;
    var b = toIndex(zeroth, first);
    var c = toIndex(first, second);
    var d = toIndex(second, third);

    var number = third;
    var previous = third % ten;

    var step: u32 = 3;
    while (step < 2000) : (step += 1) {
        number = hash(number);
        const price = number % ten;
        a = b;
        b = c;
        c = d;
        d = toIndex(previous, price);
        const index: usize = @intCast(mul_a * a + mul_b * b + mul_c * c + d);
        previous = price;
        if (seen[index] != id) {
            part_two[index] += @intCast(price);
            seen[index] = id;
        }
    }

    return number;
}

fn processSimd(chunk: [8]u32, part_two: *[130321]u16) u64 {
    var seen: [130321]u8 = undefined;
    @memset(&seen, 0xff);

    const zeroth: Vec = @bitCast(chunk);
    const first = hashVec(zeroth);
    const second = hashVec(first);
    const third = hashVec(second);

    var a: Vec = undefined;
    var b = toIndexVec(zeroth, first);
    var c = toIndexVec(first, second);
    var d = toIndexVec(second, third);

    var number = third;
    var previous = third % ten_vec;

    var step: u32 = 3;
    while (step < 2000) : (step += 1) {
        number = hashVec(number);
        const prices = number % ten_vec;
        a = b;
        b = c;
        c = d;
        d = toIndexVec(previous, prices);
        const indices = mul_a_vec * a + mul_b_vec * b + mul_c_vec * c + d;
        previous = prices;

        const idxs: [8]u32 = @bitCast(indices);
        const price_arr: [8]u32 = @bitCast(prices);
        var lane: usize = 0;
        while (lane < 8) : (lane += 1) {
            const index = @as(usize, @intCast(idxs[lane]));
            const bit: u8 = (seen[index] >> @as(u3, @intCast(lane))) & 1;
            seen[index] &= ~(@as(u8, 1) << @as(u3, @intCast(lane)));
            if (bit == 1) {
                part_two[index] += @intCast(price_arr[lane]);
            }
        }
    }

    return @as(u64, @reduce(.Add, number));
}

fn solve(input: []const u8) !Result {
    const allocator = std.heap.page_allocator;
    var numbers_list = try std.ArrayList(u32).initCapacity(allocator, 0);
    defer numbers_list.deinit(allocator);

    var idx_in: usize = 0;
    while (true) {
        const value = nextUnsigned(input, &idx_in) orelse break;
        try numbers_list.append(allocator, value);
    }

    const numbers = numbers_list.items;

    var part_two: [130321]u16 = undefined;
    @memset(&part_two, 0);

    var part_one: u64 = 0;
    const simd_chunks = numbers.len / 8;
    var chunk_index: usize = 0;
    while (chunk_index < simd_chunks) : (chunk_index += 1) {
        const base = chunk_index * 8;
        const chunk: [8]u32 = .{
            numbers[base],
            numbers[base + 1],
            numbers[base + 2],
            numbers[base + 3],
            numbers[base + 4],
            numbers[base + 5],
            numbers[base + 6],
            numbers[base + 7],
        };
        part_one += processSimd(chunk, &part_two);
    }

    var seen_scalar: [130321]u16 = undefined;
    const seen_sentinel = std.math.maxInt(u16);
    @memset(&seen_scalar, seen_sentinel);
    var id: u16 = 0;

    var i: usize = simd_chunks * 8;
    while (i < numbers.len) : (i += 1) {
        if (id == seen_sentinel) {
            @memset(&seen_scalar, seen_sentinel);
            id = 0;
        }
        part_one += processScalar(numbers[i], id, &seen_scalar, &part_two);
        id += 1;
    }

    var best: u16 = 0;
    for (part_two) |value| {
        if (value > best) best = value;
    }

    return .{ .p1 = part_one, .p2 = best };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
