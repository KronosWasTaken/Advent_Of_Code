const std = @import("std");

const Result = struct { p1: u32, p2: usize };

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const size = 12100;
    var grid = allocator.alloc(u32, size) catch unreachable;
    @memset(grid, std.math.maxInt(u32));
    
    var stack = std.ArrayList(usize){};
    defer stack.deinit(allocator);
    
    var idx: usize = 6105; 
    grid[idx] = 0;
    var part1: u32 = 0;
    
    for (input) |c| {
        const dist = grid[idx];
        
        switch (c) {
            '(' => stack.append(allocator, idx) catch unreachable,
            '|' => idx = stack.items[stack.items.len - 1],
            ')' => idx = stack.pop().?,
            'N' => idx -= 110,
            'S' => idx += 110,
            'W' => idx -= 1,
            'E' => idx += 1,
            else => {},
        }
        
        grid[idx] = @min(grid[idx], dist + 1);
        part1 = @max(part1, grid[idx]);
    }
    
    var part2: usize = 0;
    for (grid) |d| {
        if (d >= 1000 and d < std.math.maxInt(u32)) {
            part2 += 1;
        }
    }
    
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
