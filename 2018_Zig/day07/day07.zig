const std = @import("std");

const Result = struct { p1: [26:0]u8, p2: u32 };

fn solve(input: []const u8) Result {
    var deps = [_]u32{0} ** 26;
    var children = [_]std.ArrayList(u8){std.ArrayList(u8){}} ** 26;
    
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    
    for (&children) |*list| {
        list.* = std.ArrayList(u8){};
    }
    
    
    var i: usize = 0;
    while (i < input.len) {
        if (i + 36 < input.len and input[i] == 'S') {
            const from = input[i + 5] - 'A';
            const to = input[i + 36] - 'A';
            deps[to] += 1;
            children[from].append(allocator, to) catch unreachable;
            i += 49;
        } else {
            i += 1;
        }
    }
    
    
    var part1: [26:0]u8 = undefined;
    var p1_len: usize = 0;
    var done = [_]bool{false} ** 26;
    var in_degree = deps;
    
    while (p1_len < 26) {
        var found = false;
        for (0..26) |j| {
            if (!done[j] and in_degree[j] == 0) {
                part1[p1_len] = @intCast('A' + j);
                p1_len += 1;
                done[j] = true;
                found = true;
                
                for (children[j].items) |child| {
                    in_degree[child] -= 1;
                }
                break;
            }
        }
        if (!found) break;
    }
    part1[p1_len] = 0;
    
    
    const Worker = struct { finish_time: u32, task: u8 };
    var workers = std.ArrayList(Worker){};
    defer workers.deinit(allocator);
    
    var time: u32 = 0;
    var remaining = deps;
    var completed = [_]bool{false} ** 26;
    
    while (true) {
        
        while (workers.items.len < 5) {
            var next_task: ?u8 = null;
            for (0..26) |j| {
                if (!completed[j] and remaining[j] == 0) {
                    next_task = @intCast(j);
                    remaining[j] = 999; 
                    break;
                }
            }
            
            if (next_task) |task| {
                const finish = time + 61 + task;
                workers.append(allocator, .{ .finish_time = finish, .task = task }) catch unreachable;
                std.mem.sort(Worker, workers.items, {}, struct {
                    fn lessThan(_: void, a: Worker, b: Worker) bool {
                        return a.finish_time > b.finish_time;
                    }
                }.lessThan);
            } else {
                break;
            }
        }
        
        if (workers.items.len == 0) break;
        
        
        const worker = workers.pop().?;
        time = worker.finish_time;
        completed[worker.task] = true;
        
        for (children[worker.task].items) |child| {
            if (remaining[child] < 999) {
                remaining[child] -= 1;
            }
        }
    }
    
    return Result{ .p1 = part1, .p2 = time };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {s}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
