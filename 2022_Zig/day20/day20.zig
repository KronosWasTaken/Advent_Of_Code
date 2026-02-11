const std = @import("std");

const PaddedVec = struct {
    size: usize,
    vec: []u16,
};

const Result = struct {
    p1: i64,
    p2: i64,
};

fn parse(input: []const u8, allocator: std.mem.Allocator) ![]i64 {
    var values = std.ArrayListUnmanaged(i64){};
    var num: i64 = 0;
    var sign: i64 = 1;
    var in_num = false;
    for (input) |b| {
        if (b == '-') {
            sign = -1;
        } else if (b >= '0' and b <= '9') {
            num = num * 10 + @as(i64, b - '0');
            in_num = true;
        } else if (in_num) {
            values.append(allocator, num * sign) catch unreachable;
            num = 0;
            sign = 1;
            in_num = false;
        }
    }
    if (in_num) values.append(allocator, num * sign) catch unreachable;
    return values.toOwnedSlice(allocator);
}

fn position(haystack: []const u16, needle: u16) usize {
    const Vec = @Vector(64, u16);
    const NeedleVec: Vec = @splat(needle);
    var base: usize = 0;
    while (base + 64 <= haystack.len) : (base += 64) {
        const slice_ptr: *const [64]u16 = @ptrCast(haystack.ptr + base);
        const chunk: Vec = @bitCast(slice_ptr.*);
        const mask = chunk == NeedleVec;
        const bits: @Vector(64, u1) = @bitCast(mask);
        var i: usize = 0;
        while (i < 64) : (i += 1) {
            if (bits[i] == 1) return base + i;
        }
    }
    var i: usize = base;
    while (i < haystack.len) : (i += 1) {
        if (haystack[i] == needle) return i;
    }
    unreachable;
}

fn decrypt(input: []const i64, key: i64, rounds: usize, allocator: std.mem.Allocator) i64 {
    const size = input.len - 1;
    const indices = allocator.alloc(u16, input.len) catch unreachable;
    defer allocator.free(indices);
    for (indices, 0..) |*slot, i| slot.* = @intCast(i);

    var numbers = allocator.alloc(usize, input.len) catch unreachable;
    defer allocator.free(numbers);
    for (input, 0..) |n, i| numbers[i] = @intCast(@mod(n * key, @as(i64, @intCast(size))));

    var lookup = allocator.alloc(usize, input.len) catch unreachable;
    defer allocator.free(lookup);

    var skip: [16]usize = .{0} ** 16;

    var mixed: [256]PaddedVec = undefined;
    var mixed_count: usize = 0;
    const chunk = (input.len + 255) / 256;
    var second: usize = 0;
    var offset: usize = 0;
    while (second < 256 and offset < input.len) : (second += 1) {
        const len = @min(chunk, input.len - offset);
        const cap = ((len + 63) / 64) * 64;
        const vec = allocator.alloc(u16, cap) catch unreachable;
        var i: usize = 0;
        while (i < len) : (i += 1) vec[i] = indices[offset + i];
        mixed[second] = .{ .size = len, .vec = vec };
        mixed_count += 1;
        var j: usize = 0;
        while (j < len) : (j += 1) lookup[offset + j] = second;
        skip[second / 16] += len;
        offset += len;
    }

    var round: usize = 0;
    while (round < rounds) : (round += 1) {
        var index: usize = 0;
        while (index < input.len) : (index += 1) {
            const number = numbers[index];
            const sec = lookup[index];
            const first = sec / 16;
            const third = position(mixed[sec].vec[0..mixed[sec].size], @intCast(index));

            var pos = third;
            var f: usize = 0;
            while (f < first) : (f += 1) pos += skip[f];
            var s: usize = 16 * first;
            while (s < sec) : (s += 1) pos += mixed[s].size;

            var next = (pos + number) % size;

            mixed[sec].size -= 1;
            if (third < mixed[sec].size) {
                std.mem.copyForwards(u16, mixed[sec].vec[third..mixed[sec].size], mixed[sec].vec[third + 1 .. mixed[sec].size + 1]);
            }
            skip[first] -= 1;

            var fidx: usize = 0;
            while (fidx < 16) : (fidx += 1) {
                if (next > skip[fidx]) {
                    next -= skip[fidx];
                } else {
                    var sidx: usize = 0;
                    while (sidx < 16) : (sidx += 1) {
                        const sec_idx = 16 * fidx + sidx;
                        if (next > mixed[sec_idx].size) {
                            next -= mixed[sec_idx].size;
                        } else {
                            const size_before = mixed[sec_idx].size;
                            mixed[sec_idx].size += 1;
                            var insert_pos = size_before;
                            while (insert_pos > next) : (insert_pos -= 1) {
                                mixed[sec_idx].vec[insert_pos] = mixed[sec_idx].vec[insert_pos - 1];
                            }
                            mixed[sec_idx].vec[next] = @intCast(index);
                            skip[fidx] += 1;
                            lookup[index] = sec_idx;
                            break;
                        }
                    }
                    break;
                }
            }
        }
    }

    var indices_out = allocator.alloc(u16, input.len) catch unreachable;
    defer allocator.free(indices_out);
    var out_idx: usize = 0;
    var m: usize = 0;
    while (m < mixed_count) : (m += 1) {
        const pv = mixed[m];
        var i: usize = 0;
        while (i < pv.size) : (i += 1) {
            indices_out[out_idx] = pv.vec[i];
            out_idx += 1;
        }
    }

    var zeroth: usize = 0;
    while (zeroth < indices_out.len) : (zeroth += 1) {
        if (input[indices_out[zeroth]] == 0) break;
    }

    var sum: i64 = 0;
    for ([_]usize{ 1000, 2000, 3000 }) |offset2| {
        const idx = (zeroth + offset2) % indices_out.len;
        sum += input[indices_out[idx]] * key;
    }

    return sum;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const values = parse(input, allocator) catch unreachable;
    defer allocator.free(values);

    return .{ .p1 = decrypt(values, 1, 1, allocator), .p2 = decrypt(values, 811589153, 10, allocator) };
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
