const std = @import("std");

const Result = struct { p1: u64, p2: u64 };

fn game(players: usize, last: usize, allocator: std.mem.Allocator) u64 {
    const blocks = last / 23;
    const needed = 2 + 16 * blocks;
    
    var circle = allocator.alloc(u32, needed + 37) catch unreachable;
    defer allocator.free(circle);
    
    var scores = allocator.alloc(u64, players) catch unreachable;
    defer allocator.free(scores);
    @memset(scores, 0);
    
    
    const start = [_]u32{2, 20, 10, 21, 5, 22, 11, 1, 12, 6, 13, 3, 14, 7, 15, 0, 16, 8, 17, 4, 18, 19};
    @memcpy(circle[0..22], &start);
    
    var pickup: u32 = 9;
    var head: u32 = 23;
    var tail: usize = 0;
    var placed: usize = 22;
    
    for (0..blocks) |_| {
        scores[head % players] += head + pickup;
        pickup = circle[tail + 18];
        
        if (placed <= needed) {
            var idx = placed;
            inline for (0..18) |i| {
                circle[idx] = circle[tail + i];
                circle[idx + 1] = head + 1 + @as(u32, @intCast(i));
                idx += 2;
            }
            circle[idx] = head + 19;
            
            circle[tail + 16] = circle[tail + 19];
            circle[tail + 17] = head + 20;
            circle[tail + 18] = circle[tail + 20];
            circle[tail + 19] = head + 21;
            circle[tail + 20] = circle[tail + 21];
            circle[tail + 21] = head + 22;
            
            placed += 37;
        }
        
        head += 23;
        tail += 16;
    }
    
    var max_score: u64 = 0;
    for (scores) |s| {
        max_score = @max(max_score, s);
    }
    
    return max_score;
}

const GameParams = struct {
    players: usize,
    last: usize,
    result: *u64,
    allocator: std.mem.Allocator,
};

fn gameThread(params: GameParams) void {
    params.result.* = game(params.players, params.last, params.allocator);
}

fn solve(input: []const u8, allocator: std.mem.Allocator) Result {
    var nums = std.ArrayList(u32){};
    defer nums.deinit(allocator);
    
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] >= '0' and input[i] <= '9') {
            var n: u32 = 0;
            while (i < input.len and input[i] >= '0' and input[i] <= '9') {
                n = n * 10 + (input[i] - '0');
                i += 1;
            }
            nums.append(allocator, n) catch unreachable;
        } else {
            i += 1;
        }
    }
    
    const players = nums.items[0];
    const last_marble = nums.items[1];
    
    
    var part1_result: u64 = 0;
    var part2_result: u64 = 0;
    
    const thread1 = std.Thread.spawn(.{}, gameThread, .{GameParams{
        .players = players,
        .last = last_marble,
        .result = &part1_result,
        .allocator = allocator,
    }}) catch unreachable;
    
    const thread2 = std.Thread.spawn(.{}, gameThread, .{GameParams{
        .players = players,
        .last = last_marble * 100,
        .result = &part2_result,
        .allocator = allocator,
    }}) catch unreachable;
    
    thread1.join();
    thread2.join();
    
    return Result{ .p1 = part1_result, .p2 = part2_result };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input, allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
