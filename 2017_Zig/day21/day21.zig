const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
const Pattern = struct {
    three: u32,
    four: u32,
    six: u32,
    nine: [9]usize,
};
fn toIndex(a: []const u8) usize {
    var result: usize = 0;
    for (a) |bit| {
        result = (result << 1) | @as(usize, bit);
    }
    return result;
}
fn twoByTwoPermutations(a_orig: [4]u8) [8]usize {
    var indices: [8]usize = undefined;
    var a = a_orig;
    for (0..8) |i| {
        indices[i] = toIndex(&a);
        a = [4]u8{ a[2], a[0], a[3], a[1] };
        if (i == 3) {
            a = [4]u8{ a[2], a[3], a[0], a[1] };
        }
    }
    return indices;
}
fn threeByThreePermutations(a_orig: [9]u8) [8]usize {
    var indices: [8]usize = undefined;
    var a = a_orig;
    for (0..8) |i| {
        indices[i] = toIndex(&a);
        a = [9]u8{ a[6], a[3], a[0], a[7], a[4], a[1], a[8], a[5], a[2] };
        if (i == 3) {
            a = [9]u8{ a[6], a[7], a[8], a[3], a[4], a[5], a[0], a[1], a[2] };
        }
    }
    return indices;
}
fn solve(input: []const u8) Result {
    const gpa = std.heap.page_allocator;
    var pattern_lookup = [_]usize{0} ** 16;
    var two_to_three = [_][9]u8{[_]u8{0} ** 9} ** 16;
    var three_to_four = [_][16]u8{[_]u8{0} ** 16} ** 512;
    var todo: std.ArrayList(usize) = .{};
    defer todo.deinit(gpa);
    todo.append(gpa, 143) catch unreachable;
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        const bit = struct {
            fn f(l: []const u8, i: usize) u8 {
                return l[i] & 1;
            }
        }.f;
        if (line.len == 20) {
            const from = [4]u8{ bit(line, 0), bit(line, 1), bit(line, 3), bit(line, 4) };
            const value = [9]u8{
                bit(line, 9),  bit(line, 10), bit(line, 11),
                bit(line, 13), bit(line, 14), bit(line, 15),
                bit(line, 17), bit(line, 18), bit(line, 19),
            };
            const pattern = todo.items.len;
            todo.append(gpa, toIndex(&value)) catch unreachable;
            for (twoByTwoPermutations(from)) |key| {
                two_to_three[key] = value;
                pattern_lookup[key] = pattern;
            }
        } else {
            const from = [9]u8{
                bit(line, 0), bit(line, 1), bit(line, 2),
                bit(line, 4), bit(line, 5), bit(line, 6),
                bit(line, 8), bit(line, 9), bit(line, 10),
            };
            const value = [16]u8{
                bit(line, 15), bit(line, 16), bit(line, 17), bit(line, 18),
                bit(line, 20), bit(line, 21), bit(line, 22), bit(line, 23),
                bit(line, 25), bit(line, 26), bit(line, 27), bit(line, 28),
                bit(line, 30), bit(line, 31), bit(line, 32), bit(line, 33),
            };
            for (threeByThreePermutations(from)) |key| {
                three_to_four[key] = value;
            }
        }
    }
    var patterns: std.ArrayList(Pattern) = .{};
    defer patterns.deinit(gpa);
    for (todo.items) |index| {
        const four = three_to_four[index];
        var six = [_]u8{0} ** 36;
        const coords = [_]struct { src: usize, dst: usize }{
            .{ .src = 0, .dst = 0 },
            .{ .src = 2, .dst = 3 },
            .{ .src = 8, .dst = 18 },
            .{ .src = 10, .dst = 21 },
        };
        for (coords) |coord| {
            const idx = toIndex(&[4]u8{
                four[coord.src],
                four[coord.src + 1],
                four[coord.src + 4],
                four[coord.src + 5],
            });
            const replacement = two_to_three[idx];
            @memcpy(six[coord.dst .. coord.dst + 3], replacement[0..3]);
            @memcpy(six[coord.dst + 6 .. coord.dst + 9], replacement[3..6]);
            @memcpy(six[coord.dst + 12 .. coord.dst + 15], replacement[6..9]);
        }
        const offsets = [9]usize{ 0, 2, 4, 12, 14, 16, 24, 26, 28 };
        var nine: [9]usize = undefined;
        for (offsets, 0..) |i, idx| {
            const key_idx = toIndex(&[4]u8{
                six[i],
                six[i + 1],
                six[i + 6],
                six[i + 7],
            });
            nine[idx] = pattern_lookup[key_idx];
        }
        var three: u32 = 0;
        var i: u32 = 0;
        while (i < 9) : (i += 1) {
            if (((index >> @intCast(i)) & 1) == 1) three += 1;
        }
        var four_sum: u32 = 0;
        for (four) |bit| {
            four_sum += bit;
        }
        var six_sum: u32 = 0;
        for (six) |bit| {
            six_sum += bit;
        }
        patterns.append(gpa, .{
            .three = three,
            .four = four_sum,
            .six = six_sum,
            .nine = nine,
        }) catch unreachable;
    }
    var current: std.ArrayList(u64) = .{};
    defer current.deinit(gpa);
    current.resize(gpa, patterns.items.len) catch unreachable;
    @memset(current.items, 0);
    var result: std.ArrayList(u32) = .{};
    defer result.deinit(gpa);
    current.items[0] = 1;
    for (0..7) |_| {
        var three: u64 = 0;
        var four: u64 = 0;
        var six: u64 = 0;
        var next: std.ArrayList(u64) = .{};
        defer next.deinit(gpa);
        next.resize(gpa, patterns.items.len) catch unreachable;
        @memset(next.items, 0);
        for (current.items, 0..) |count, i| {
            const pattern = patterns.items[i];
            three += count * pattern.three;
            four += count * pattern.four;
            six += count * pattern.six;
            for (pattern.nine) |j| {
                next.items[j] += count;
            }
        }
        result.append(gpa, @intCast(three)) catch unreachable;
        result.append(gpa, @intCast(four)) catch unreachable;
        result.append(gpa, @intCast(six)) catch unreachable;
        current.clearRetainingCapacity();
        current.appendSlice(gpa, next.items) catch unreachable;
    }
    const p1 = result.items[5];
    const p2 = result.items[18];
    return .{ .p1 = p1, .p2 = p2 };
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