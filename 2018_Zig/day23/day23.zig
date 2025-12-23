const std = @import("std");

const Result = struct { p1: usize, p2: i32 };

const Nanobot = struct {
    x: i32,
    y: i32,
    z: i32,
    r: i32,
    
    fn manhattan(self: Nanobot, other: Nanobot) i32 {
        return @intCast(@abs(self.x - other.x) + @abs(self.y - other.y) + @abs(self.z - other.z));
    }
};

const Cube = struct {
    x1: i32, x2: i32,
    y1: i32, y2: i32,
    z1: i32, z2: i32,
    
    fn inRange(self: Cube, nb: Nanobot) bool {
        const x = @max(0, self.x1 - nb.x) + @max(0, nb.x - self.x2);
        const y = @max(0, self.y1 - nb.y) + @max(0, nb.y - self.y2);
        const z = @max(0, self.z1 - nb.z) + @max(0, nb.z - self.z2);
        return x + y + z <= nb.r;
    }
    
    fn closest(self: Cube) i32 {
        const x: i32 = @intCast(@min(@abs(self.x1), @abs(self.x2)));
        const y: i32 = @intCast(@min(@abs(self.y1), @abs(self.y2)));
        const z: i32 = @intCast(@min(@abs(self.z1), @abs(self.z2)));
        return x + y + z;
    }
    
    fn size(self: Cube) i32 {
        return self.x2 - self.x1 + 1;
    }
    
    fn split(self: Cube) [8]Cube {
        const lx = @divTrunc(self.x1 + self.x2, 2);
        const ly = @divTrunc(self.y1 + self.y2, 2);
        const lz = @divTrunc(self.z1 + self.z2, 2);
        const ux = lx + 1;
        const uy = ly + 1;
        const uz = lz + 1;
        
        return [_]Cube{
            .{ .x1 = self.x1, .x2 = lx, .y1 = self.y1, .y2 = ly, .z1 = self.z1, .z2 = lz },
            .{ .x1 = ux, .x2 = self.x2, .y1 = self.y1, .y2 = ly, .z1 = self.z1, .z2 = lz },
            .{ .x1 = self.x1, .x2 = lx, .y1 = uy, .y2 = self.y2, .z1 = self.z1, .z2 = lz },
            .{ .x1 = ux, .x2 = self.x2, .y1 = uy, .y2 = self.y2, .z1 = self.z1, .z2 = lz },
            .{ .x1 = self.x1, .x2 = lx, .y1 = self.y1, .y2 = ly, .z1 = uz, .z2 = self.z2 },
            .{ .x1 = ux, .x2 = self.x2, .y1 = self.y1, .y2 = ly, .z1 = uz, .z2 = self.z2 },
            .{ .x1 = self.x1, .x2 = lx, .y1 = uy, .y2 = self.y2, .z1 = uz, .z2 = self.z2 },
            .{ .x1 = ux, .x2 = self.x2, .y1 = uy, .y2 = self.y2, .z1 = uz, .z2 = self.z2 },
        };
    }
};

const State = struct {
    in_range: usize,
    distance: i32,
    size: i32,
    cube: Cube,
};

fn lessThan(_: void, a: State, b: State) std.math.Order {
    if (a.in_range != b.in_range) return std.math.order(b.in_range, a.in_range);
    if (a.distance != b.distance) return std.math.order(a.distance, b.distance);
    return std.math.order(a.size, b.size);
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var bots = std.ArrayList(Nanobot){};
    defer bots.deinit(allocator);
    
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
                bots.append(allocator, .{
                    .x = nums.items[0],
                    .y = nums.items[1],
                    .z = nums.items[2],
                    .r = nums.items[3],
                }) catch unreachable;
                nums.clearRetainingCapacity();
            }
        } else {
            i += 1;
        }
    }
    
    
    var strongest = bots.items[0];
    for (bots.items) |bot| {
        if (bot.r > strongest.r) strongest = bot;
    }
    
    var part1: usize = 0;
    for (bots.items) |bot| {
        if (strongest.manhattan(bot) <= strongest.r) {
            part1 += 1;
        }
    }
    
    
    const SIZE: i32 = 1 << 29;
    var pq = std.PriorityQueue(State, void, lessThan).init(allocator, {});
    defer pq.deinit();
    
    const initial_cube = Cube{ .x1 = -SIZE, .x2 = SIZE - 1, .y1 = -SIZE, .y2 = SIZE - 1, .z1 = -SIZE, .z2 = SIZE - 1 };
    var in_range: usize = 0;
    for (bots.items) |bot| {
        if (initial_cube.inRange(bot)) in_range += 1;
    }
    
    pq.add(State{
        .in_range = in_range,
        .distance = initial_cube.closest(),
        .size = initial_cube.size(),
        .cube = initial_cube,
    }) catch unreachable;
    
    var part2: i32 = 0;
    while (pq.removeOrNull()) |state| {
        if (state.cube.size() == 1) {
            part2 = state.cube.closest();
            break;
        }
        
        for (state.cube.split()) |next_cube| {
            var next_in_range: usize = 0;
            for (bots.items) |bot| {
                if (next_cube.inRange(bot)) next_in_range += 1;
            }
            
            pq.add(State{
                .in_range = next_in_range,
                .distance = next_cube.closest(),
                .size = next_cube.size(),
                .cube = next_cube,
            }) catch unreachable;
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
