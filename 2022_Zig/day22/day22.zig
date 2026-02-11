const std = @import("std");

const Tile = enum(u8) { None, Open, Wall };

const Move = union(enum) {
    Left,
    Right,
    Forward: u32,
};

const Point = struct {
    x: i32,
    y: i32,

    fn add(self: Point, other: Point) Point {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    fn sub(self: Point, other: Point) Point {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    fn clockwise(self: Point) Point {
        return .{ .x = -self.y, .y = self.x };
    }

    fn counterClockwise(self: Point) Point {
        return .{ .x = self.y, .y = -self.x };
    }
};

const Vector = struct {
    x: i32,
    y: i32,
    z: i32,

    fn neg(self: Vector) Vector {
        return .{ .x = -self.x, .y = -self.y, .z = -self.z };
    }
};

const Face = struct {
    corner: Point,
    i: Vector,
    j: Vector,
    k: Vector,
};

const Grid = struct {
    width: usize,
    height: usize,
    tiles: []Tile,
    start: i32,
    block: i32,

    fn tile(self: *const Grid, point: Point) Tile {
        const x = point.x;
        const y = point.y;
        if (x >= 0 and y >= 0 and @as(usize, @intCast(x)) < self.width and @as(usize, @intCast(y)) < self.height) {
            return self.tiles[@as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x))];
        }
        return .None;
    }
};

const Input = struct {
    grid: Grid,
    moves: []Move,
};

const Result = struct {
    p1: i32,
    p2: i32,
};

const RIGHT = Point{ .x = 1, .y = 0 };
const LEFT = Point{ .x = -1, .y = 0 };
const UP = Point{ .x = 0, .y = -1 };
const DOWN = Point{ .x = 0, .y = 1 };

fn gcd(a: usize, b: usize) usize {
    var x = a;
    var y = b;
    while (y != 0) {
        const t = x % y;
        x = y;
        y = t;
    }
    return x;
}

fn parseGrid(input: []const u8, allocator: std.mem.Allocator) !Grid {
    var lines = std.ArrayListUnmanaged([]const u8){};
    defer lines.deinit(allocator);

    var start: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        const b = input[i];
        var newline_len: usize = 0;
        if (b == '\r') {
            newline_len = if (i + 1 < input.len and input[i + 1] == '\n') 2 else 1;
        } else if (b == '\n') {
            newline_len = 1;
        }
        if (newline_len > 0) {
            lines.append(allocator, input[start..i]) catch unreachable;
            start = i + newline_len;
            i += newline_len;
            continue;
        }
        i += 1;
    }
    if (start < input.len) lines.append(allocator, input[start..]) catch unreachable;

    var width: usize = 0;
    for (lines.items) |line| {
        if (line.len > width) width = line.len;
    }
    const height = lines.items.len;

    var tiles = try allocator.alloc(Tile, width * height);
    @memset(tiles, .None);

    var y: usize = 0;
    while (y < height) : (y += 1) {
        const row = lines.items[y];
        var x: usize = 0;
        while (x < row.len) : (x += 1) {
            tiles[y * width + x] = switch (row[x]) {
                '.' => .Open,
                '#' => .Wall,
                else => .None,
            };
        }
    }

    const start_pos = @as(i32, @intCast(std.mem.indexOfScalar(Tile, tiles, .Open).?));
    const block = @as(i32, @intCast(gcd(width, height)));

    return .{ .width = width, .height = height, .tiles = tiles, .start = start_pos, .block = block };
}

fn parseMoves(input: []const u8, allocator: std.mem.Allocator) ![]Move {
    var moves = std.ArrayListUnmanaged(Move){};
    var num: u32 = 0;
    var in_num = false;
    for (input) |b| {
        if (b >= '0' and b <= '9') {
            num = num * 10 + (b - '0');
            in_num = true;
        } else if (in_num) {
            moves.append(allocator, .{ .Forward = num }) catch unreachable;
            num = 0;
            in_num = false;
            if (b == 'L') moves.append(allocator, .Left) catch unreachable;
            if (b == 'R') moves.append(allocator, .Right) catch unreachable;
        }
    }
    if (in_num) moves.append(allocator, .{ .Forward = num }) catch unreachable;
    return moves.toOwnedSlice(allocator);
}

fn parse(input: []const u8, allocator: std.mem.Allocator) !Input {
    const split = std.mem.lastIndexOf(u8, input, "\n\n") orelse std.mem.lastIndexOf(u8, input, "\r\n\r\n") orelse input.len;
    const grid = try parseGrid(input[0..split], allocator);
    const moves = try parseMoves(input[split..], allocator);
    return .{ .grid = grid, .moves = moves };
}

fn password(input: *const Input, ctx: anytype, handle_none: anytype) i32 {
    var position = Point{ .x = input.grid.start, .y = 0 };
    var direction = RIGHT;

    for (input.moves) |command| {
        switch (command) {
            .Left => direction = direction.counterClockwise(),
            .Right => direction = direction.clockwise(),
            .Forward => |n| {
                var step: u32 = 0;
                while (step < n) : (step += 1) {
                    const next = position.add(direction);
                    switch (input.grid.tile(next)) {
                        .Wall => break,
                        .Open => position = next,
                        .None => {
                            const out = handle_none(ctx, position, direction);
                            const next_pos = out[0];
                            const next_dir = out[1];
                            if (input.grid.tile(next_pos) == .Open) {
                                position = next_pos;
                                direction = next_dir;
                            } else {
                                break;
                            }
                        },
                    }
                }
            },
        }
    }

    const position_score = 1000 * (position.y + 1) + 4 * (position.x + 1);
    const direction_score: i32 = if (direction.x == 1) 0 else if (direction.y == 1) 1 else if (direction.x == -1) 2 else 3;
    return position_score + direction_score;
}

fn part1(input: *const Input) i32 {
    const block = input.grid.block;
    const ctx_handle = struct {
        fn call(grid: *const Grid, position: Point, direction: Point, step: i32) [2]Point {
            const reverse = Point{ .x = -direction.x * step, .y = -direction.y * step };
            var next = position.add(reverse);
            while (grid.tile(next) != .None) {
                next = next.add(reverse);
            }
            next = next.add(direction);
            return .{ next, direction };
        }
    };
    var ctx = struct {
        grid: *const Grid,
        step: i32,
    }{ .grid = &input.grid, .step = block };
    const handler = struct {
        fn call(context: *const @TypeOf(ctx), position: Point, direction: Point) [2]Point {
            return ctx_handle.call(context.grid, position, direction, context.step);
        }
    };
    return password(input, &ctx, handler.call);
}

fn part2(input: *const Input, allocator: std.mem.Allocator) i32 {
    const grid = &input.grid;
    const block = grid.block;
    var queue = std.ArrayListUnmanaged(Face){};
    defer queue.deinit(allocator);

    const start = Face{ .corner = Point{ .x = grid.start - @mod(grid.start, block), .y = 0 }, .i = .{ .x = 1, .y = 0, .z = 0 }, .j = .{ .x = 0, .y = 1, .z = 0 }, .k = .{ .x = 0, .y = 0, .z = 1 } };
    queue.append(allocator, start) catch unreachable;

    var faces = std.AutoHashMap(Vector, Face).init(allocator);
    var corners = std.AutoHashMap(Point, Face).init(allocator);
    defer faces.deinit();
    defer corners.deinit();
    faces.put(start.k, start) catch unreachable;
    corners.put(start.corner, start) catch unreachable;

    var head: usize = 0;
    while (head < queue.items.len) : (head += 1) {
        const next = queue.items[head];
        const corner = next.corner;
        const i = next.i;
        const j = next.j;
        const k = next.k;

        const neighbors = [_]Face{
            .{ .corner = corner.add(Point{ .x = -block, .y = 0 }), .i = k.neg(), .j = j, .k = i },
            .{ .corner = corner.add(Point{ .x = block, .y = 0 }), .i = k, .j = j, .k = i.neg() },
            .{ .corner = corner.add(Point{ .x = 0, .y = -block }), .i = i, .j = k.neg(), .k = j },
            .{ .corner = corner.add(Point{ .x = 0, .y = block }), .i = i, .j = k, .k = j.neg() },
        };

        for (neighbors) |cand| {
            if (grid.tile(cand.corner) != .None and !faces.contains(cand.k)) {
                queue.append(allocator, cand) catch unreachable;
                faces.put(cand.k, cand) catch unreachable;
                corners.put(cand.corner, cand) catch unreachable;
            }
        }
    }

    var ctx = struct {
        faces: *const std.AutoHashMap(Vector, Face),
        corners: *const std.AutoHashMap(Point, Face),
        block: i32,
        edge: i32,
    }{ .faces = &faces, .corners = &corners, .block = block, .edge = block - 1 };

    const handler = struct {
        fn call(context: *const @TypeOf(ctx), position: Point, direction: Point) [2]Point {
            const offset = Point{ .x = @mod(position.x, context.block), .y = @mod(position.y, context.block) };
            const corner = position.sub(offset);
            const face = context.corners.get(corner).?;
            const next_k = if (direction.x == -1) face.i else if (direction.x == 1) face.i.neg() else if (direction.y == -1) face.j else face.j.neg();
            const next_face = context.faces.get(next_k).?;
            const next_direction = if (face.k.x == next_face.i.x and face.k.y == next_face.i.y and face.k.z == next_face.i.z) RIGHT else if (face.k.x == -next_face.i.x and face.k.y == -next_face.i.y and face.k.z == -next_face.i.z) LEFT else if (face.k.x == next_face.j.x and face.k.y == next_face.j.y and face.k.z == next_face.j.z) DOWN else UP;

            const next_offset = if (direction.x == -1) blk: {
                if (next_direction.x == -1) break :blk Point{ .x = context.edge, .y = offset.y };
                if (next_direction.x == 1) break :blk Point{ .x = 0, .y = context.edge - offset.y };
                if (next_direction.y == 1) break :blk Point{ .x = offset.y, .y = 0 };
                break :blk Point{ .x = context.edge - offset.y, .y = context.edge };
            } else if (direction.x == 1) blk: {
                if (next_direction.x == -1) break :blk Point{ .x = context.edge, .y = context.edge - offset.y };
                if (next_direction.x == 1) break :blk Point{ .x = 0, .y = offset.y };
                if (next_direction.y == 1) break :blk Point{ .x = context.edge - offset.y, .y = 0 };
                break :blk Point{ .x = offset.y, .y = context.edge };
            } else if (direction.y == 1) blk: {
                if (next_direction.x == -1) break :blk Point{ .x = context.edge, .y = offset.x };
                if (next_direction.x == 1) break :blk Point{ .x = 0, .y = context.edge - offset.x };
                if (next_direction.y == 1) break :blk Point{ .x = offset.x, .y = 0 };
                break :blk Point{ .x = context.edge - offset.x, .y = context.edge };
            } else blk: {
                if (next_direction.x == -1) break :blk Point{ .x = context.edge, .y = context.edge - offset.x };
                if (next_direction.x == 1) break :blk Point{ .x = 0, .y = offset.x };
                if (next_direction.y == 1) break :blk Point{ .x = context.edge - offset.x, .y = 0 };
                break :blk Point{ .x = offset.x, .y = context.edge };
            };

            const next_position = next_face.corner.add(next_offset);
            return .{ next_position, next_direction };
        }
    };

    return password(input, &ctx, handler.call);
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    var parsed = parse(input, allocator) catch unreachable;
    defer {
        allocator.free(parsed.grid.tiles);
        allocator.free(parsed.moves);
    }

    return .{ .p1 = part1(&parsed), .p2 = part2(&parsed, allocator) };
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
