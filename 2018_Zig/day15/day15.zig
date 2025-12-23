const std = @import("std");

const Result = struct { p1: i32, p2: i32 };

const Point = struct {
    x: i32,
    y: i32,
    
    fn new(x: i32, y: i32) Point {
        return .{ .x = x, .y = y };
    }
    
    fn add(self: Point, other: Point) Point {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }
    
    fn readingOrder(self: Point) i32 {
        return 32 * self.y + self.x;
    }
};

const Kind = enum { elf, goblin };

const Unit = struct {
    position: Point,
    kind: Kind,
    health: i32,
    power: i32,
};

const READING_ORDER = [_]Point{ Point.new(0, -1), Point.new(-1, 0), Point.new(1, 0), Point.new(0, 1) };

fn setBit(slice: []u32, point: Point) void {
    slice[@intCast(point.y)] |= @as(u32, 1) << @intCast(point.x);
}

fn expand(walls: []const u32, frontier: []u32) bool {
    var previous = frontier[0];
    var changed: u32 = 0;
    
    for (1..31) |i| {
        const current = frontier[i];
        const next = frontier[i + 1];
        
        frontier[i] = (previous | (current << 1) | current | (current >> 1) | next) & ~walls[i];
        
        previous = current;
        changed |= current ^ frontier[i];
    }
    
    return changed != 0;
}

fn intersect(in_range: []const u32, frontier: []const u32) ?Point {
    for (1..31) |i| {
        const both = in_range[i] & frontier[i];
        if (both != 0) {
            const x = @ctz(both);
            const y: i32 = @intCast(i);
            return Point.new(x, y);
        }
    }
    return null;
}

fn doubleBfs(walls_orig: [32]u32, units: []const Unit, point: Point, kind: Kind, allocator: std.mem.Allocator) ?Point {
    var walls = walls_orig;
    const frontier = allocator.alloc(u32, 32) catch unreachable;
    defer allocator.free(frontier);
    @memset(frontier, 0);
    setBit(frontier, point);
    
    const in_range = allocator.alloc(u32, 32) catch unreachable;
    defer allocator.free(in_range);
    @memset(in_range, 0);
    
    for (units) |unit| {
        if (unit.health > 0) {
            if (unit.kind == kind) {
                setBit(&walls, unit.position);
            } else {
                setBit(in_range, unit.position);
            }
        }
    }
    
    
    _ = expand(&walls, in_range);
    
    while (expand(&walls, frontier)) {
        if (intersect(in_range, frontier)) |target| {
            
            const rev_frontier = allocator.alloc(u32, 32) catch unreachable;
            defer allocator.free(rev_frontier);
            @memset(rev_frontier, 0);
            setBit(rev_frontier, target);
            
            const rev_in_range = allocator.alloc(u32, 32) catch unreachable;
            defer allocator.free(rev_in_range);
            @memset(rev_in_range, 0);
            setBit(rev_in_range, point);
            _ = expand(&walls, rev_in_range);
            
            while (true) {
                _ = expand(&walls, rev_frontier);
                if (intersect(rev_in_range, rev_frontier)) |result| {
                    return result;
                }
            }
        }
    }
    
    return null;
}

fn attack(grid: []const ?usize, units: []const Unit, point: Point, kind: Kind) ?usize {
    var enemy_health: i32 = std.math.maxInt(i32);
    var enemy_index: ?usize = null;
    
    for (READING_ORDER) |offset| {
        const next_point = point.add(offset);
        const idx = grid[@intCast(next_point.y * 32 + next_point.x)];
        if (idx) |i| {
            if (units[i].kind != kind and units[i].health < enemy_health) {
                enemy_health = units[i].health;
                enemy_index = i;
            }
        }
    }
    
    return enemy_index;
}

fn fight(walls: [32]u32, elves_in: []const Point, goblins_in: []const Point, elf_attack_power: i32, part_two: bool, allocator: std.mem.Allocator) ?i32 {
    var units = std.ArrayList(Unit){};
    defer units.deinit(allocator);
    
    var elves_count = elves_in.len;
    var goblins_count = goblins_in.len;
    
    for (elves_in) |pos| {
        units.append(allocator, .{ .position = pos, .kind = .elf, .health = 200, .power = elf_attack_power }) catch unreachable;
    }
    for (goblins_in) |pos| {
        units.append(allocator, .{ .position = pos, .kind = .goblin, .health = 200, .power = 3 }) catch unreachable;
    }
    
    var grid = allocator.alloc(?usize, 32 * 32) catch unreachable;
    defer allocator.free(grid);
    
    var turn: i32 = 0;
    while (true) : (turn += 1) {
        
        var i: usize = 0;
        while (i < units.items.len) {
            if (units.items[i].health <= 0) {
                _ = units.swapRemove(i);
            } else {
                i += 1;
            }
        }
        
        
        std.mem.sort(Unit, units.items, {}, struct {
            fn lessThan(_: void, a: Unit, b: Unit) bool {
                return a.position.readingOrder() < b.position.readingOrder();
            }
        }.lessThan);
        
        
        @memset(grid, null);
        for (units.items, 0..) |unit, idx| {
            grid[@intCast(unit.position.y * 32 + unit.position.x)] = idx;
        }
        
        for (0..units.items.len) |index| {
            const unit = units.items[index];
            
            if (unit.health <= 0) continue;
            
            if (elves_count == 0 or goblins_count == 0) {
                var total: i32 = 0;
                for (units.items) |u| {
                    if (u.health > 0) total += u.health;
                }
                return turn * total;
            }
            
            var nearby = attack(grid, units.items, unit.position, unit.kind);
            
            if (nearby == null) {
                if (doubleBfs(walls, units.items, unit.position, unit.kind, allocator)) |next| {
                    grid[@intCast(unit.position.y * 32 + unit.position.x)] = null;
                    grid[@intCast(next.y * 32 + next.x)] = index;
                    units.items[index].position = next;
                    
                    nearby = attack(grid, units.items, next, unit.kind);
                }
            }
            
            if (nearby) |target| {
                units.items[target].health -= unit.power;
                
                if (units.items[target].health <= 0) {
                    grid[@intCast(units.items[target].position.y * 32 + units.items[target].position.x)] = null;
                    
                    if (units.items[target].kind == .elf) {
                        if (part_two) return null;
                        elves_count -= 1;
                    } else {
                        goblins_count -= 1;
                    }
                }
            }
        }
    }
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var walls = [_]u32{0} ** 32;
    var elves = std.ArrayList(Point){};
    defer elves.deinit(allocator);
    var goblins = std.ArrayList(Point){};
    defer goblins.deinit(allocator);
    
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    var y: i32 = 0;
    while (lines.next()) |line| : (y += 1) {
        for (line, 0..) |c, x| {
            const pos = Point.new(@intCast(x), y);
            switch (c) {
                '#' => setBit(&walls, pos),
                'E' => elves.append(allocator, pos) catch unreachable,
                'G' => goblins.append(allocator, pos) catch unreachable,
                else => {},
            }
        }
    }
    
    const part1 = fight(walls, elves.items, goblins.items, 3, false, allocator).?;
    
    var elf_power: i32 = 4;
    var part2: i32 = 0;
    while (true) : (elf_power += 1) {
        if (fight(walls, elves.items, goblins.items, elf_power, true, allocator)) |result| {
            part2 = result;
            break;
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
