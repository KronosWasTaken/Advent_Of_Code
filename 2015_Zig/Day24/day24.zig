const std = @import("std");
const State = struct {
    weight: u32,
    packages: u32, // Bitmask
};
fn combinations(packages: []const u32, groups: u32) u64 {
    @setRuntimeSafety(false);
    const target = blk: {
        var sum: u32 = 0;
        for (packages) |p| sum += p;
        break :blk sum / groups;
    };
    var buffer: [200000]State = undefined;
    var read_start: usize = 0;
    var read_end: usize = 1;
    var write_start: usize = 100000;
    buffer[0] = .{ .weight = 0, .packages = 0 };
    while (read_start < read_end) {
        var write_end = write_start;
        var r = read_start;
        while (r < read_end) : (r += 1) {
            const state = buffer[r];
            const start = if (state.packages == 0) 0 else @as(usize, @intCast(32 - @clz(state.packages)));
            var i = start;
            while (i < packages.len) : (i += 1) {
                const next_weight = state.weight + packages[i];
                if (next_weight > target) break;
                const next_packages = state.packages | (@as(u32, 1) << @intCast(i));
                if (next_weight == target) {
                    var qe: u64 = 1;
                    var mask = next_packages;
                    var idx: u5 = 0;
                    while (mask != 0) {
                        if ((mask & 1) != 0) {
                            qe *= packages[idx];
                        }
                        mask >>= 1;
                        idx += 1;
                    }
                    return qe;
                }
                buffer[write_end] = .{ .weight = next_weight, .packages = next_packages };
                write_end += 1;
            }
        }
        if (write_start == 100000) {
            read_start = 100000;
            read_end = write_end;
            write_start = 0;
        } else {
            read_start = 0;
            read_end = write_end;
            write_start = 100000;
        }
    }
    return 0;
}
fn solve(input: []const u8) struct { p1: u64, p2: u64 } {
    var packages: [30]u32 = undefined;
    var count: usize = 0;
    var num: u32 = 0;
    var in_number = false;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            num = num * 10 + (c - '0');
            in_number = true;
        } else if (in_number) {
            packages[count] = num;
            count += 1;
            num = 0;
            in_number = false;
        }
    }
    if (in_number) {
        packages[count] = num;
        count += 1;
    }
    std.mem.sort(u32, packages[0..count], {}, comptime std.sort.asc(u32));
    const p1 = combinations(packages[0..count], 3);
    const p2 = combinations(packages[0..count], 4);
    return .{ .p1 = p1, .p2 = p2 };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {d} | Part 2: {d}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
