const std = @import("std");

const Result = struct { p1: usize, p2: i32 };

const Point3D = struct {
    x: i32,
    y: i32,
    z: i32,

    fn transform(self: Point3D, index: usize) Point3D {
        const x = self.x;
        const y = self.y;
        const z = self.z;
        return switch (index) {
            0 => .{ .x = x, .y = y, .z = z },
            1 => .{ .x = x, .y = z, .z = -y },
            2 => .{ .x = x, .y = -z, .z = y },
            3 => .{ .x = x, .y = -y, .z = -z },
            4 => .{ .x = -x, .y = -z, .z = -y },
            5 => .{ .x = -x, .y = y, .z = -z },
            6 => .{ .x = -x, .y = -y, .z = z },
            7 => .{ .x = -x, .y = z, .z = y },
            8 => .{ .x = y, .y = z, .z = x },
            9 => .{ .x = y, .y = -x, .z = z },
            10 => .{ .x = y, .y = x, .z = -z },
            11 => .{ .x = y, .y = -z, .z = -x },
            12 => .{ .x = -y, .y = x, .z = z },
            13 => .{ .x = -y, .y = z, .z = -x },
            14 => .{ .x = -y, .y = -z, .z = x },
            15 => .{ .x = -y, .y = -x, .z = -z },
            16 => .{ .x = z, .y = x, .z = y },
            17 => .{ .x = z, .y = y, .z = -x },
            18 => .{ .x = z, .y = -y, .z = x },
            19 => .{ .x = z, .y = -x, .z = -y },
            20 => .{ .x = -z, .y = y, .z = x },
            21 => .{ .x = -z, .y = -x, .z = y },
            22 => .{ .x = -z, .y = x, .z = -y },
            23 => .{ .x = -z, .y = -y, .z = -x },
            else => self,
        };
    }

    fn euclidean(self: Point3D, other: Point3D) i32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        return dx * dx + dy * dy + dz * dz;
    }

    fn abs(value: i32) i32 {
        return if (value < 0) -value else value;
    }

    fn manhattan(self: Point3D, other: Point3D) i32 {
        return abs(self.x - other.x) + abs(self.y - other.y) + abs(self.z - other.z);
    }
};

const Scanner = struct {
    beacons: []Point3D,
    signature: std.AutoHashMap(i32, [2]usize),
};

const Located = struct {
    beacons: []Point3D,
    signature: std.AutoHashMap(i32, [2]usize),
    oriented: std.AutoHashMap(Point3D, void),
    translation: Point3D,
};

const Found = struct {
    orientation: usize,
    translation: Point3D,
};

fn parseScanner(block: []const u8, allocator: std.mem.Allocator) ?Scanner {
    var lines = std.mem.splitScalar(u8, block, '\n');
    _ = lines.next();

    var beacons_list = std.ArrayListUnmanaged(Point3D){};
    defer beacons_list.deinit(allocator);

    while (lines.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, "\r");
        if (line.len == 0) continue;

        var values: [3]i32 = undefined;
        var idx: usize = 0;
        var value: i32 = 0;
        var sign: i32 = 1;
        var in_num = false;
        for (line) |c| {
            if (c == '-') {
                sign = -1;
                continue;
            }
            if (c >= '0' and c <= '9') {
                value = value * 10 + @as(i32, c - '0');
                in_num = true;
                continue;
            }
            if (in_num) {
                values[idx] = value * sign;
                idx += 1;
                value = 0;
                sign = 1;
                in_num = false;
            }
        }
        if (in_num and idx < 3) {
            values[idx] = value * sign;
            idx += 1;
        }
        if (idx == 3) {
            beacons_list.append(allocator, .{ .x = values[0], .y = values[1], .z = values[2] }) catch unreachable;
        }
    }

    if (beacons_list.items.len == 0) return null;

    const beacons = allocator.alloc(Point3D, beacons_list.items.len) catch unreachable;
    std.mem.copyForwards(Point3D, beacons, beacons_list.items);

    var signature = std.AutoHashMap(i32, [2]usize).init(allocator);
    const expected_pairs = beacons.len * (beacons.len - 1) / 2;
    signature.ensureTotalCapacity(@intCast(expected_pairs)) catch unreachable;

    var a: usize = 0;
    while (a + 1 < beacons.len) : (a += 1) {
        var b: usize = a + 1;
        while (b < beacons.len) : (b += 1) {
            const key = beacons[a].euclidean(beacons[b]);
            signature.putAssumeCapacity(key, .{ a, b });
        }
    }
    return .{ .beacons = beacons, .signature = signature };
}

fn locatedFrom(scanner: Scanner, found: Found, allocator: std.mem.Allocator) Located {
    const count = scanner.beacons.len;
    const beacons = allocator.alloc(Point3D, count) catch unreachable;
    var oriented = std.AutoHashMap(Point3D, void).init(allocator);
    oriented.ensureTotalCapacity(@intCast(count)) catch unreachable;

    var i: usize = 0;
    while (i < count) : (i += 1) {
        const point = scanner.beacons[i].transform(found.orientation);
        const moved = Point3D{ .x = point.x + found.translation.x, .y = point.y + found.translation.y, .z = point.z + found.translation.z };
        beacons[i] = moved;
        oriented.putAssumeCapacity(moved, {});
    }
    return .{ .beacons = beacons, .signature = scanner.signature, .oriented = oriented, .translation = found.translation };
}

fn detailedCheck(known: *const Located, scanner: *const Scanner, points: [4]Point3D) ?Found {
    const a = points[0];
    const b = points[1];
    const x = points[2];
    const y = points[3];
    const delta = Point3D{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };

    var orientation: usize = 0;
    while (orientation < 24) : (orientation += 1) {
        const rotate_x = x.transform(orientation);
        const rotate_y = y.transform(orientation);

        var translation: Point3D = undefined;
        if (rotate_x.x - rotate_y.x == delta.x and rotate_x.y - rotate_y.y == delta.y and rotate_x.z - rotate_y.z == delta.z) {
            translation = Point3D{ .x = b.x - rotate_y.x, .y = b.y - rotate_y.y, .z = b.z - rotate_y.z };
        } else if (rotate_y.x - rotate_x.x == delta.x and rotate_y.y - rotate_x.y == delta.y and rotate_y.z - rotate_x.z == delta.z) {
            translation = Point3D{ .x = b.x - rotate_x.x, .y = b.y - rotate_x.y, .z = b.z - rotate_x.z };
        } else {
            continue;
        }

        var count: usize = 0;
        for (scanner.beacons) |candidate| {
            const point = candidate.transform(orientation);
            const moved = Point3D{ .x = point.x + translation.x, .y = point.y + translation.y, .z = point.z + translation.z };
            if (known.oriented.contains(moved)) {
                count += 1;
                if (count == 12) return .{ .orientation = orientation, .translation = translation };
            }
        }
    }
    return null;
}

fn check(known: *const Located, scanner: *const Scanner) ?Found {
    var matching: usize = 0;
    var it = known.signature.iterator();
    while (it.next()) |entry| {
        if (scanner.signature.contains(entry.key_ptr.*)) {
            matching += 1;
            if (matching == 66) {
                const ab = entry.value_ptr.*;
                const xy = scanner.signature.get(entry.key_ptr.*).?;
                const points = [4]Point3D{ known.beacons[ab[0]], known.beacons[ab[1]], scanner.beacons[xy[0]], scanner.beacons[xy[1]] };
                return detailedCheck(known, scanner, points);
            }
        }
    }
    return null;
}

fn normalizeInput(input: []const u8, allocator: std.mem.Allocator) []u8 {
    var out = std.ArrayListUnmanaged(u8){};
    out.ensureTotalCapacity(allocator, input.len) catch unreachable;
    for (input) |c| if (c != '\r') out.append(allocator, c) catch unreachable;
    return out.toOwnedSlice(allocator) catch unreachable;
}

fn parse(input: []const u8, allocator: std.mem.Allocator) []Located {
    const normalized = normalizeInput(input, allocator);
    defer allocator.free(normalized);

    var scanners = std.ArrayListUnmanaged(Scanner){};
    defer scanners.deinit(allocator);

    var blocks = std.mem.splitSequence(u8, normalized, "\n\n");
    while (blocks.next()) |block| {
        if (block.len == 0) continue;
        if (parseScanner(block, allocator)) |scanner| {
            scanners.append(allocator, scanner) catch unreachable;
        }
    }

    var unknown = std.ArrayListUnmanaged(Scanner){};
    defer unknown.deinit(allocator);
    unknown.appendSlice(allocator, scanners.items) catch unreachable;

    var todo = std.ArrayListUnmanaged(Located){};
    var done = std.ArrayListUnmanaged(Located){};
    defer todo.deinit(allocator);
    defer done.deinit(allocator);

    const first = unknown.pop().?;
    todo.append(allocator, locatedFrom(first, .{ .orientation = 0, .translation = Point3D{ .x = 0, .y = 0, .z = 0 } }, allocator)) catch unreachable;

    while (todo.items.len > 0) {
        const known = todo.pop().?;
        var next_unknown = std.ArrayListUnmanaged(Scanner){};
        while (unknown.items.len > 0) {
            const scanner = unknown.pop().?;
            if (check(&known, &scanner)) |found| {
                todo.append(allocator, locatedFrom(scanner, found, allocator)) catch unreachable;
            } else {
                next_unknown.append(allocator, scanner) catch unreachable;
            }
        }
        done.append(allocator, known) catch unreachable;
        unknown.deinit(allocator);
        unknown = next_unknown;
    }

    const result = allocator.alloc(Located, done.items.len) catch unreachable;
    std.mem.copyForwards(Located, result, done.items);
    return result;
}

fn part1(located: []Located) usize {
    var set = std.AutoHashMap(Point3D, void).init(std.heap.page_allocator);
    defer set.deinit();
    for (located) |loc| {
        for (loc.beacons) |b| set.put(b, {}) catch unreachable;
    }
    return set.count();
}

fn part2(located: []Located) i32 {
    var max: i32 = 0;
    for (located) |a| {
        for (located) |b| {
            const d = a.translation.manhattan(b.translation);
            if (d > max) max = d;
        }
    }
    return max;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const located = parse(input, allocator);
    defer allocator.free(located);
    return .{ .p1 = part1(located), .p2 = part2(located) };
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
