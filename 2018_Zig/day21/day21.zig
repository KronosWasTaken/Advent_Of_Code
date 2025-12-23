const std = @import("std");

const Result = struct { p1: u64, p2: u64 };

fn step(seed: u64, hash: u64) u64 {
    var c = seed;
    var d = hash | 0x10000;
    
    for (0..3) |_| {
        c = (c + (d & 0xff)) & 0xffffff;
        c = (c * 65899) & 0xffffff;
        d >>= 8;
    }
    
    return c;
}

fn solve(input: []const u8) Result {
    
    var nums = std.ArrayList(u64){};
    defer nums.deinit(std.heap.page_allocator);
    
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] >= '0' and input[i] <= '9') {
            var n: u64 = 0;
            while (i < input.len and input[i] >= '0' and input[i] <= '9') {
                n = n * 10 + (input[i] - '0');
                i += 1;
            }
            nums.append(std.heap.page_allocator, n) catch unreachable;
        } else {
            i += 1;
        }
    }
    
    const seed = nums.items[22];
    
    
    const part1 = step(seed, 0);
    
    
    var seen = std.AutoHashMap(u64, void).init(std.heap.page_allocator);
    defer seen.deinit();
    
    var prev: u64 = 0;
    var hash: u64 = 0;
    
    while (seen.get(hash) == null) {
        seen.put(hash, {}) catch unreachable;
        prev = hash;
        hash = step(seed, hash);
    }
    
    return Result{ .p1 = part1, .p2 = prev };
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
