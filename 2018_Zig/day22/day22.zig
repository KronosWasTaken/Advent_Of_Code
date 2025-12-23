const std = @import("std");

const Result = struct { p1: i32, p2: i32 };

const Point = struct { x: i32, y: i32 };

const Region = struct {
    erosion: i32,
    minutes: [3]i32,
};

const State = struct {
    point: Point,
    tool: usize,
    time: i32,
};

const BUCKETS = 8;
const TORCH = 1;

fn scanCave(depth: i32, target_x: i32, target_y: i32, width: i32, height: i32, allocator: std.mem.Allocator) []Region {
    var grid = allocator.alloc(Region, @intCast(width * height)) catch unreachable;
    
    for (grid) |*r| {
        r.erosion = 0;
        r.minutes = [_]i32{std.math.maxInt(i32)} ** 3;
    }
    
    
    const g0 = &grid[0];
    g0.erosion = @mod(depth, 20183);
    g0.minutes[@intCast(@mod(g0.erosion, 3))] = 0;
    
    
    for (1..@intCast(width)) |x| {
        const geo = x * 16807 + @as(usize, @intCast(depth));
        const idx = x;
        grid[idx].erosion = @intCast(@mod(@as(i64, @intCast(geo)), 20183));
        grid[idx].minutes[@intCast(@mod(grid[idx].erosion, 3))] = 0;
    }
    
    
    for (1..@intCast(height)) |y| {
        const row_start = y * @as(usize, @intCast(width));
        const geo = y * 48271 + @as(usize, @intCast(depth));
        grid[row_start].erosion = @intCast(@mod(@as(i64, @intCast(geo)), 20183));
        grid[row_start].minutes[@intCast(@mod(grid[row_start].erosion, 3))] = 0;
        
        var prev = grid[row_start].erosion;
        
        for (1..@intCast(width)) |x| {
            const idx = row_start + x;
            const px: i32 = @intCast(x);
            const py: i32 = @intCast(y);
            
            if (px == target_x and py == target_y) {
                grid[idx].erosion = @mod(depth, 20183);
            } else {
                const up = grid[idx - @as(usize, @intCast(width))].erosion;
                const geo_val = @as(i64, prev) * @as(i64, up) + depth;
                grid[idx].erosion = @intCast(@mod(geo_val, 20183));
            }
            grid[idx].minutes[@intCast(@mod(grid[idx].erosion, 3))] = 0;
            prev = grid[idx].erosion;
        }
    }
    
    return grid;
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    
    var nums = std.ArrayList(i32){};
    defer nums.deinit(allocator);
    
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] >= '0' and input[i] <= '9') {
            var n: i32 = 0;
            while (i < input.len and input[i] >= '0' and input[i] <= '9') {
                n = n * 10 + @as(i32, input[i] - '0');
                i += 1;
            }
            nums.append(allocator, n) catch unreachable;
        } else {
            i += 1;
        }
    }
    
    const depth = nums.items[0];
    const target_x = nums.items[1];
    const target_y = nums.items[2];
    
    
    const width1 = target_x + 1;
    const height1 = target_y + 1;
    const cave1 = scanCave(depth, target_x, target_y, width1, height1, allocator);
    
    var part1: i32 = 0;
    for (cave1) |r| {
        part1 += @mod(r.erosion, 3);
    }
    
    
    const width2 = target_x + 50;
    const height2 = target_y + 50;
    const cave = scanCave(depth, target_x, target_y, width2, height2, allocator);
    
    var buckets: [BUCKETS]std.ArrayList(State) = undefined;
    for (&buckets) |*b| {
        b.* = std.ArrayList(State).initCapacity(allocator, 1000) catch unreachable;
    }
    
    buckets[0].append(allocator, State{ .point = .{ .x = 0, .y = 0 }, .tool = TORCH, .time = 0 }) catch unreachable;
    cave[0].minutes[TORCH] = 0;
    
    var base: usize = 0;
    var part2: i32 = 0;
    
    outer: while (true) : (base += 1) {
        while (buckets[base % BUCKETS].items.len > 0) {
            const item = buckets[base % BUCKETS].pop() orelse continue;
            const point = item.point;
            const tool = item.tool;
            const time = item.time;
            const idx = @as(usize, @intCast(point.y * width2 + point.x));
            
            if (time > cave[idx].minutes[tool]) {
                continue;
            }
            
            if (point.x == target_x and point.y == target_y) {
                if (tool == TORCH) {
                    part2 = time;
                    break :outer;
                }
            }
            
            
            const dirs = [_]Point{ .{ .x = 0, .y = -1 }, .{ .x = -1, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 0, .y = 1 } };
            for (dirs) |d| {
                const nx = point.x + d.x;
                const ny = point.y + d.y;
                if (nx >= 0 and ny >= 0 and nx < width2 and ny < height2) {
                    const nidx = @as(usize, @intCast(ny * width2 + nx));
                    if (time + 1 < cave[nidx].minutes[tool]) {
                        const manhattan: i32 = @intCast(@abs(nx - target_x) + @abs(ny - target_y));
                        const priority = @as(usize, @intCast(time + 1 + manhattan));
                        
                        cave[nidx].minutes[tool] = time + 1;
                        buckets[priority % BUCKETS].append(allocator, State{ .point = .{ .x = nx, .y = ny }, .tool = tool, .time = time + 1 }) catch unreachable;
                    }
                }
            }
            
            
            for (0..3) |other| {
                if (time + 7 < cave[idx].minutes[other]) {
                    const manhattan: i32 = @intCast(@abs(point.x - target_x) + @abs(point.y - target_y));
                    const priority = @as(usize, @intCast(time + 7 + manhattan));
                    
                    cave[idx].minutes[other] = time + 7;
                    buckets[priority % BUCKETS].append(allocator, State{ .point = point, .tool = other, .time = time + 7 }) catch unreachable;
                }
            }
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
