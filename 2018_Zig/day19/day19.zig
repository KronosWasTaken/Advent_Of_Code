const std = @import("std");

const Result = struct { p1: u32, p2: u32 };

fn divisorSum(n: u32) u32 {
    var sum: u32 = 1;
    var num = n;
    var f: u32 = 2;
    
    while (f * f <= num) {
        var g = sum;
        while (num % f == 0) {
            num /= f;
            g *= f;
            sum += g;
        }
        f += 1;
    }
    
    return if (num == 1) sum else sum * (1 + num);
}

fn solve(input: []const u8) Result {
    
    var nums = std.ArrayList(u32){};
    defer nums.deinit(std.heap.page_allocator);
    
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] >= '0' and input[i] <= '9') {
            var n: u32 = 0;
            while (i < input.len and input[i] >= '0' and input[i] <= '9') {
                n = n * 10 + (input[i] - '0');
                i += 1;
            }
            nums.append(std.heap.page_allocator, n) catch unreachable;
        } else {
            i += 1;
        }
    }
    
    
    const base = 22 * nums.items[65] + nums.items[71];
    const n1 = base + 836;
    const n2 = base + 10551236;
    
    return Result{ .p1 = divisorSum(n1), .p2 = divisorSum(n2) };
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
