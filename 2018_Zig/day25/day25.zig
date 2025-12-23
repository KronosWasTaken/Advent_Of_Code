const std = @import("std");

const Result = struct { p1: usize };

const Point = struct { x: i32, y: i32, z: i32, w: i32 };

fn manhattan(a: Point, b: Point) i32 {
    const dx: i32 = @intCast(@abs(a.x - b.x));
    const dy: i32 = @intCast(@abs(a.y - b.y));
    const dz: i32 = @intCast(@abs(a.z - b.z));
    const dw: i32 = @intCast(@abs(a.w - b.w));
    return dx + dy + dz + dw;
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var points = std.ArrayList(Point){};
    defer points.deinit(allocator);
    
    var nums = std.ArrayList(i32){};
    defer nums.deinit(allocator);
    
    var i: usize = 0;
    var neg = false;
    while (i < input.len) {
        if (input[i] == '-') {
            neg = true;
            i += 1;
        } else if (input[i] >= '0' and input[i] <= '9') {
            var n: i32 = 0;
            while (i < input.len and input[i] >= '0' and input[i] <= '9') {
                n = n * 10 + @as(i32, input[i] - '0');
                i += 1;
            }
            nums.append(allocator, if (neg) -n else n) catch unreachable;
            neg = false;
            
            if (nums.items.len == 4) {
                points.append(allocator, .{
                    .x = nums.items[0],
                    .y = nums.items[1],
                    .z = nums.items[2],
                    .w = nums.items[3],
                }) catch unreachable;
                nums.clearRetainingCapacity();
            }
        } else {
            i += 1;
        }
    }
    
    var constellations: usize = 0;
    var remaining = std.ArrayList(Point){};
    defer remaining.deinit(allocator);
    remaining.appendSlice(allocator, points.items) catch unreachable;
    
    var todo = std.ArrayList(Point){};
    defer todo.deinit(allocator);
    
    while (remaining.items.len > 0) {
        constellations += 1;
        todo.append(allocator, remaining.pop().?) catch unreachable;
        
        while (todo.items.len > 0) {
            const point = todo.pop().?;
            var j: usize = 0;
            
            while (j < remaining.items.len) {
                if (manhattan(point, remaining.items[j]) <= 3) {
                    todo.append(allocator, remaining.swapRemove(j)) catch unreachable;
                } else {
                    j += 1;
                }
            }
        }
    }
    
    return Result{ .p1 = constellations };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
