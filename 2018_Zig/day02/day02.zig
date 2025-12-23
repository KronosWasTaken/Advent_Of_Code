const std = @import("std");

const Result = struct { p1: u32, p2: []const u8 };

fn solve(input: []const u8, allocator: std.mem.Allocator) Result {
    var ids = std.ArrayList([]const u8){};
    defer ids.deinit(allocator);
    
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        ids.append(allocator, line) catch unreachable;
    }
    
    
    var twos: u32 = 0;
    var threes: u32 = 0;
    
    for (ids.items) |id| {
        var freq = [_]u8{0} ** 26;
        for (id) |c| {
            freq[c - 'a'] += 1;
        }
        
        var has_two = false;
        var has_three = false;
        for (freq) |f| {
            if (f == 2) has_two = true;
            if (f == 3) has_three = true;
        }
        
        if (has_two) twos += 1;
        if (has_three) threes += 1;
    }
    
    const part1 = twos * threes;
    
    
    const width = ids.items[0].len;
    var part2_result: []u8 = "";
    
    for (ids.items, 0..) |id1, i| {
        for (i+1..ids.items.len) |j| {
            const id2 = ids.items[j];
            var diffs: usize = 0;
            var diff_pos: usize = 0;
            
            for (0..width) |k| {
                if (id1[k] != id2[k]) {
                    diffs += 1;
                    diff_pos = k;
                    if (diffs > 1) break;
                }
            }
            
            if (diffs == 1) {
                
                var result = allocator.alloc(u8, width - 1) catch unreachable;
                var m: usize = 0;
                for (0..width) |k| {
                    if (k != diff_pos) {
                        result[m] = id1[k];
                        m += 1;
                    }
                }
                part2_result = result;
                break;
            }
        }
        if (part2_result.len > 0) break;
    }
    
    return Result{ .p1 = part1, .p2 = part2_result };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input, allocator);
    
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: ", .{});
    for (result.p2) |c| {
        std.debug.print("{c}", .{c});
    }
    std.debug.print("\n", .{});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
