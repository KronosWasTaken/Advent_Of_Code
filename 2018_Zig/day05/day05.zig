const std = @import("std");

const Result = struct { p1: usize, p2: usize };

fn collapse(polymer: []const u8, ignore: u8, allocator: std.mem.Allocator) []const u8 {
    var head: u8 = 0;
    var stack = std.ArrayList(u8).initCapacity(allocator, 10000) catch unreachable;
    
    for (polymer) |unit| {
        
        if ((unit | 32) == ignore) continue;
        
        
        if ((head ^ unit) == 32) {
            
            head = if (stack.items.len > 0) stack.pop().? else 0;
        } else {
            
            if (head != 0) {
                stack.append(allocator, head) catch unreachable;
            }
            head = unit;
        }
    }
    
    if (head != 0) {
        stack.append(allocator, head) catch unreachable;
    }
    
    return stack.items;
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    
    var end = input.len;
    while (end > 0 and input[end - 1] < 'A') end -= 1;
    const polymer = input[0..end];
    
    
    const reacted = collapse(polymer, 0, allocator);
    const part1 = reacted.len;
    
    
    var part2 = part1;
    for ('a'..'z' + 1) |kind| {
        const len = collapse(reacted, @intCast(kind), allocator).len;
        part2 = @min(part2, len);
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
