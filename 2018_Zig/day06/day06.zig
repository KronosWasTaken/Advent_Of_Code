const std = @import("std");

const Result = struct { p1: i32, p2: i32 };

const Point = struct {
    x: i32,
    y: i32,
};

const Cell = struct {
    id: i16,
    distance: i16,
};

fn solve(input: []const u8, allocator: std.mem.Allocator) Result {
    
    var coords = std.ArrayList(Point){};
    defer coords.deinit(allocator);
    
    var i: usize = 0;
    var nums: [2]i32 = undefined;
    var num_idx: usize = 0;
    
    while (i < input.len) {
        if (input[i] >= '0' and input[i] <= '9') {
            var n: i32 = 0;
            while (i < input.len and input[i] >= '0' and input[i] <= '9') {
                n = n * 10 + @as(i32, input[i] - '0');
                i += 1;
            }
            nums[num_idx] = n;
            num_idx += 1;
            if (num_idx == 2) {
                coords.append(allocator, Point{ .x = nums[0], .y = nums[1] }) catch unreachable;
                num_idx = 0;
            }
        } else {
            i += 1;
        }
    }
    
    
    var min_x: i32 = std.math.maxInt(i32);
    var min_y: i32 = std.math.maxInt(i32);
    var max_x: i32 = std.math.minInt(i32);
    var max_y: i32 = std.math.minInt(i32);
    var sum_x: i32 = 0;
    var sum_y: i32 = 0;
    
    for (coords.items) |*c| {
        min_x = @min(min_x, c.x);
        min_y = @min(min_y, c.y);
        max_x = @max(max_x, c.x);
        max_y = @max(max_y, c.y);
        sum_x += c.x;
        sum_y += c.y;
    }
    
    
    for (coords.items) |*c| {
        c.x -= min_x;
        c.y -= min_y;
        sum_x -= min_x;
        sum_y -= min_y;
    }
    
    const width = max_x - min_x + 1;
    const height = max_y - min_y + 1;
    
    
    var grid = allocator.alloc(Cell, @intCast(width * height)) catch unreachable;
    defer allocator.free(grid);
    @memset(grid, Cell{ .id = 0, .distance = 0 });
    
    var frontier = std.ArrayList(Point){};
    defer frontier.deinit(allocator);
    var next = std.ArrayList(Point){};
    defer next.deinit(allocator);
    
    
    for (coords.items, 0..) |p, id| {
        grid[@intCast(p.y * width + p.x)].id = @intCast(id + 1);
        frontier.append(allocator, p) catch unreachable;
    }
    
    
    var dist: i16 = 1;
    while (frontier.items.len > 0) : (dist += 1) {
        for (frontier.items) |p| {
            const idx = @as(usize, @intCast(p.y * width + p.x));
            const cur = grid[idx];
            
            
            const directions = [_][2]i32{ .{0, -1}, .{-1, 0}, .{1, 0}, .{0, 1} };
            for (directions) |d| {
                const nx = p.x + d[0];
                const ny = p.y + d[1];
                
                if (nx >= 0 and nx < width and ny >= 0 and ny < height) {
                    const nidx = @as(usize, @intCast(ny * width + nx));
                    var neighbor = &grid[nidx];
                    
                    if (neighbor.id != 0) {
                        if (neighbor.id != cur.id and neighbor.distance == dist) {
                            neighbor.id = -1; 
                        }
                    } else {
                        neighbor.id = cur.id;
                        neighbor.distance = dist;
                        next.append(allocator, Point{ .x = nx, .y = ny }) catch unreachable;
                    }
                }
            }
        }
        
        frontier.clearRetainingCapacity();
        std.mem.swap(std.ArrayList(Point), &frontier, &next);
    }
    
    
    var areas = allocator.alloc(i32, coords.items.len + 2) catch unreachable;
    defer allocator.free(areas);
    @memset(areas, 0);
    
    
    for (0..@intCast(width)) |x| {
        areas[@intCast(grid[x].id + 1)] = std.math.minInt(i32);
        areas[@intCast(grid[(@as(usize, @intCast(height)) - 1) * @as(usize, @intCast(width)) + x].id + 1)] = std.math.minInt(i32);
    }
    
    
    for (0..@intCast(height)) |y| {
        const row_start = y * @as(usize, @intCast(width));
        areas[@intCast(grid[row_start].id + 1)] = std.math.minInt(i32);
        areas[@intCast(grid[row_start + @as(usize, @intCast(width)) - 1].id + 1)] = std.math.minInt(i32);
        
        
        if (y >= 1 and y < @as(usize, @intCast(height)) - 1) {
            for (1..@as(usize, @intCast(width)) - 1) |x| {
                const cell_id = grid[row_start + x].id;
                if (areas[@intCast(cell_id + 1)] != std.math.minInt(i32)) {
                    areas[@intCast(cell_id + 1)] += 1;
                }
            }
        }
    }
    
    var part1: i32 = 0;
    for (areas) |area| {
        part1 = @max(part1, area);
    }
    
    
    
    var x_dist = allocator.alloc(i32, @intCast(width)) catch unreachable;
    defer allocator.free(x_dist);
    @memset(x_dist, 0);
    
    var y_dist = allocator.alloc(i32, @intCast(height)) catch unreachable;
    defer allocator.free(y_dist);
    @memset(y_dist, 0);
    
    
    for (coords.items) |p| {
        x_dist[@intCast(p.x)] += 1;
        y_dist[@intCast(p.y)] += 1;
    }
    
    
    var distance_sum = sum_x;
    var delta: i32 = @intCast(coords.items.len);
    
    for (x_dist) |*d| {
        const count = d.*;
        delta -= count * 2;
        d.* = distance_sum;
        distance_sum -= delta;
    }
    
    distance_sum = sum_y;
    delta = @intCast(coords.items.len);
    
    for (y_dist) |*d| {
        const count = d.*;
        delta -= count * 2;
        d.* = distance_sum;
        distance_sum -= delta;
    }
    
    
    const SAFE = 10000;
    const n_points: i32 = @intCast(coords.items.len);
    
    var x_extended = std.ArrayList(i32){};
    defer x_extended.deinit(allocator);
    for (x_dist) |d| x_extended.append(allocator, d) catch unreachable;
    
    var k = x_dist[@intCast(width - 1)] + n_points;
    while (k < SAFE) : (k += n_points) {
        x_extended.append(allocator, k) catch unreachable;
    }
    k = x_dist[0] + n_points;
    while (k < SAFE) : (k += n_points) {
        x_extended.append(allocator, k) catch unreachable;
    }
    std.mem.sort(i32, x_extended.items, {}, comptime std.sort.asc(i32));
    
    var y_extended = std.ArrayList(i32){};
    defer y_extended.deinit(allocator);
    for (y_dist) |d| y_extended.append(allocator, d) catch unreachable;
    
    k = y_dist[@intCast(height - 1)] + n_points;
    while (k < SAFE) : (k += n_points) {
        y_extended.append(allocator, k) catch unreachable;
    }
    k = y_dist[0] + n_points;
    while (k < SAFE) : (k += n_points) {
        y_extended.append(allocator, k) catch unreachable;
    }
    std.mem.sort(i32, y_extended.items, {}, comptime std.sort.asc(i32));
    
    
    var part2: i32 = 0;
    var y_idx: usize = y_extended.items.len - 1;
    
    for (x_extended.items) |x| {
        while (y_idx > 0 and y_extended.items[y_idx] + x >= SAFE) {
            y_idx -= 1;
        }
        if (y_extended.items[y_idx] + x < SAFE) {
            part2 += @intCast(y_idx + 1);
        } else {
            break;
        }
    }
    
    return Result{ .p1 = part1, .p2 = part2 };
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
