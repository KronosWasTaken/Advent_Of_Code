const std = @import("std");

const Result = struct { p1: usize, p2: usize };

fn fill(map: *std.AutoHashMap([2]i32, u8), x: i32, y: i32, d: i32) void {
    var cx = x;
    while (map.get(.{cx, y}) orelse '.' == '|') {
        map.put(.{cx, y}, '~') catch unreachable;
        cx += d;
    }
}

fn flow(map: *std.AutoHashMap([2]i32, u8), ymax: i32, x: i32, y: i32, d: i32) bool {
    if (y > ymax) return true;
    
    const current = map.get(.{x, y}) orelse '.';
    if (current != '.') {
        return current == '|';
    }
    
    map.put(.{x, y}, '|') catch unreachable;
    
    if (flow(map, ymax, x, y + 1, 0)) return true;
    
    const left_leak = if (d != 1) flow(map, ymax, x - 1, y, -1) else false;
    const right_leak = if (d != -1) flow(map, ymax, x + 1, y, 1) else false;
    
    if (left_leak or right_leak) return true;
    
    if (d == 0) {
        fill(map, x, y, -1);
        fill(map, x + 1, y, 1);
    }
    
    return false;
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var map = std.AutoHashMap([2]i32, u8).init(allocator);
    defer map.deinit();
    
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var nums: [3]i32 = undefined;
        var idx: usize = 0;
        var i: usize = 0;
        
        while (i < line.len and idx < 3) {
            if (line[i] >= '0' and line[i] <= '9') {
                var n: i32 = 0;
                while (i < line.len and line[i] >= '0' and line[i] <= '9') {
                    n = n * 10 + @as(i32, line[i] - '0');
                    i += 1;
                }
                nums[idx] = n;
                idx += 1;
            } else {
                i += 1;
            }
        }
        
        if (idx == 3) {
            const s = nums[0];
            const a = nums[1];
            const b = nums[2];
            const hori = line[0] == 'x';
            
            var t = a;
            while (t <= b) : (t += 1) {
                const pos: [2]i32 = if (hori) .{s, t} else .{t, s};
                map.put(pos, '#') catch unreachable;
            }
        }
    }
    
    var ymin: i32 = std.math.maxInt(i32);
    var ymax: i32 = std.math.minInt(i32);
    
    var iter = map.keyIterator();
    while (iter.next()) |key| {
        ymin = @min(ymin, key[1]);
        ymax = @max(ymax, key[1]);
    }
    
    _ = flow(&map, ymax, 500, 0, 0);
    
    var water: usize = 0;
    var flows: usize = 0;
    
    iter = map.keyIterator();
    while (iter.next()) |key| {
        const y = key[1];
        if (y >= ymin) {
            const val = map.get(key.*).?;
            if (val == '~') water += 1;
            if (val == '|') flows += 1;
        }
    }
    
    return Result{ .p1 = water + flows, .p2 = water };
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
