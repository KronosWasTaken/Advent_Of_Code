const std = @import("std");

const Result = struct { p1: u32, p2: u32 };

fn parseNode(nums: []const u8, idx: *usize, stack: *std.ArrayList(u32), part1: *u32, allocator: std.mem.Allocator) u32 {
    const n_child = nums[idx.*];
    idx.* += 1;
    const n_meta = nums[idx.*];
    idx.* += 1;
    
    const stack_base = stack.items.len;
    
    
    for (0..n_child) |_| {
        const child_val = parseNode(nums, idx, stack, part1, allocator);
        stack.append(allocator, child_val) catch unreachable;
    }
    
    var value: u32 = 0;
    
    
    for (0..n_meta) |_| {
        const meta = nums[idx.*];
        idx.* += 1;
        part1.* += meta;
        
        if (n_child == 0) {
            value += meta;
        } else if (meta > 0 and meta <= n_child) {
            value += stack.items[stack_base + meta - 1];
        }
    }
    
    stack.items.len = stack_base;
    return value;
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var nums = std.ArrayList(u8){};
    defer nums.deinit(allocator);
    
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] >= '0' and input[i] <= '9') {
            var n: u8 = 0;
            while (i < input.len and input[i] >= '0' and input[i] <= '9') {
                n = n * 10 + (input[i] - '0');
                i += 1;
            }
            nums.append(allocator, n) catch unreachable;
        } else {
            i += 1;
        }
    }
    
    var stack = std.ArrayList(u32){};
    defer stack.deinit(allocator);
    
    var part1: u32 = 0;
    var idx: usize = 0;
    const part2 = parseNode(nums.items, &idx, &stack, &part1, allocator);
    
    return Result{ .p1 = part1, .p2 = part2 };
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
