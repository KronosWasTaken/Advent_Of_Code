const std = @import("std");

const Result = struct { p1: i64, p2: i64 };

fn score(plants: []const u8, base: i64) i64 {
    var result: i64 = 0;
    for (plants, 0..) |plant, i| {
        if (plant == 1) {
            result += base + @as(i64, @intCast(i));
        }
    }
    return result;
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    const first_line = lines.next().?;
    
    var plants = std.ArrayList(u8){};
    defer plants.deinit(allocator);
    
    var i: usize = 15;
    while (i < first_line.len) : (i += 1) {
        plants.append(allocator, if (first_line[i] == '#') 1 else 0) catch unreachable;
    }
    
    var rules = [_]u8{0} ** 32;
    while (lines.next()) |line| {
        if (line.len < 10) continue;
        var pattern: u8 = 0;
        for (0..5) |j| {
            pattern = (pattern << 1) | (if (line[j] == '#') @as(u8, 1) else 0);
        }
        rules[pattern] = if (line[9] == '#') @as(u8, 1) else 0;
    }
    
    var base: i64 = 0;
    var part1: i64 = 0;
    var part2: i64 = 0;
    var generation: i64 = 0;
    
    while (true) {
        var next_plants = std.ArrayList(u8){};
        defer next_plants.deinit(allocator);
        
        var offset: usize = 0;
        while (offset < plants.items.len and plants.items[offset] == 0) : (offset += 1) {}
        
        var pattern: u8 = 0;
        const new_base = base + @as(i64, @intCast(offset)) - 2;
        
        var idx = offset;
        while (idx < plants.items.len) : (idx += 1) {
            pattern = ((pattern << 1) | plants.items[idx]) & 0b11111;
            next_plants.append(allocator, rules[pattern]) catch unreachable;
        }
        
        pattern = (pattern << 1) & 0b11111;
        while (pattern != 0) {
            next_plants.append(allocator, rules[pattern]) catch unreachable;
            pattern = (pattern << 1) & 0b11111;
        }
        
        while (next_plants.items.len > 0 and next_plants.items[next_plants.items.len - 1] == 0) {
            _ = next_plants.pop();
        }
        
        generation += 1;
        
        if (generation >= 20) {
            if (generation == 20) {
                part1 = score(next_plants.items, new_base);
            } else if (std.mem.eql(u8, plants.items, next_plants.items)) {
                const current_score = score(next_plants.items, new_base);
                const prev_score = score(plants.items, base);
                const delta = current_score - prev_score;
                part2 = current_score + delta * (50_000_000_000 - generation);
                break;
            }
        }
        
        plants.clearRetainingCapacity();
        plants.appendSlice(allocator, next_plants.items) catch unreachable;
        base = new_base;
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
