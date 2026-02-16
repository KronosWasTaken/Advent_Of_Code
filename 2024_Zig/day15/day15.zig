const std = @import("std");

const Result = struct {
    p1: i32,
    p2: i32,
};

const Pos = struct { x: i32, y: i32 };
const Dir = Pos;

fn add(a: Pos, b: Pos) Pos {
    return .{ .x = a.x + b.x, .y = a.y + b.y };
}

const LEFT = Dir{ .x = -1, .y = 0 };
const RIGHT = Dir{ .x = 1, .y = 0 };
const UP = Dir{ .x = 0, .y = -1 };
const DOWN = Dir{ .x = 0, .y = 1 };

const Grid = struct {
    width: usize,
    height: usize,
    cells: []u8,

    fn index(self: Grid, pos: Pos) usize {
        return @as(usize, @intCast(pos.y)) * self.width + @as(usize, @intCast(pos.x));
    }

    fn get(self: Grid, pos: Pos) u8 {
        return self.cells[self.index(pos)];
    }

    fn set(self: Grid, pos: Pos, value: u8) void {
        self.cells[self.index(pos)] = value;
    }
};

fn parse(input: []const u8, allocator: std.mem.Allocator) !struct { grid: Grid, moves: []const u8 } {
    const sep = std.mem.indexOf(u8, input, "\r\n\r\n") orelse std.mem.indexOf(u8, input, "\n\n") orelse input.len;
    const prefix = input[0..sep];
    var suffix: []const u8 = "";
    if (sep < input.len) {
        const jump: usize = if (input[sep] == '\r') 4 else 2;
        if (sep + jump <= input.len) {
            suffix = input[sep + jump ..];
        }
    }

    var lines: std.ArrayListUnmanaged([]const u8) = .{};
    defer lines.deinit(allocator);
    var splitter = std.mem.splitScalar(u8, prefix, '\n');
    while (splitter.next()) |line_raw| {
        var line = line_raw;
        if (line.len == 0) continue;
        if (line[line.len - 1] == '\r') {
            line = line[0 .. line.len - 1];
        }
        try lines.append(allocator, line);
    }

    const height = lines.items.len;
    const width = if (height > 0) lines.items[0].len else 0;
    var cells = try allocator.alloc(u8, width * height);
    var y: usize = 0;
    while (y < height) : (y += 1) {
        const row = lines.items[y];
        @memcpy(cells[y * width ..][0..width], row);
    }

    return .{ .grid = .{ .width = width, .height = height, .cells = cells }, .moves = suffix };
}

fn find(grid: Grid, needle: u8) Pos {
    var y: usize = 0;
    while (y < grid.height) : (y += 1) {
        var x: usize = 0;
        while (x < grid.width) : (x += 1) {
            const pos = Pos{ .x = @intCast(x), .y = @intCast(y) };
            if (grid.get(pos) == needle) return pos;
        }
    }
    return .{ .x = 0, .y = 0 };
}

fn narrow(grid: Grid, start: *Pos, direction: Pos) void {
    var position = add(start.*, direction);
    var size: usize = 1;
    while (grid.get(position) != '.' and grid.get(position) != '#') {
        position = add(position, direction);
        size += 1;
    }
    if (grid.get(position) == '.') {
        var previous: u8 = '.';
        position = add(start.*, direction);
        var i: usize = 0;
        while (i < size) : (i += 1) {
            const idx = grid.index(position);
            std.mem.swap(u8, &previous, &grid.cells[idx]);
            position = add(position, direction);
        }
        start.* = add(start.*, direction);
    }
}

fn wide(grid: Grid, start: *Pos, direction: Pos, todo: *std.ArrayListUnmanaged(Pos), allocator: std.mem.Allocator) void {
    if (grid.get(add(start.*, direction)) == '.') {
        start.* = add(start.*, direction);
        return;
    }
    todo.clearRetainingCapacity();
    _ = todo.append(allocator, .{ .x = 0, .y = 0 }) catch unreachable;
    _ = todo.append(allocator, start.*) catch unreachable;

    var index: usize = 1;
    while (index < todo.items.len) : (index += 1) {
        const next = add(todo.items[index], direction);
        const cell = grid.get(next);
        var first: Pos = undefined;
        var second: Pos = undefined;
        switch (cell) {
            '[' => {
                first = next;
                second = add(next, RIGHT);
            },
            ']' => {
                first = add(next, LEFT);
                second = next;
            },
            '#' => return,
            else => continue,
        }
        if (first.x != todo.items[todo.items.len - 2].x or first.y != todo.items[todo.items.len - 2].y) {
            _ = todo.append(allocator, first) catch unreachable;
            _ = todo.append(allocator, second) catch unreachable;
        }
    }

    var rev_index: usize = todo.items.len;
    while (rev_index > 2) {
        rev_index -= 1;
        const point = todo.items[rev_index];
        const to = add(point, direction);
        grid.set(to, grid.get(point));
        grid.set(point, '.');
    }

    start.* = add(start.*, direction);
}

fn stretch(grid: Grid, allocator: std.mem.Allocator) !Grid {
    var cells = try allocator.alloc(u8, grid.width * 2 * grid.height);
    @memset(cells, '.');
    var y: usize = 0;
    while (y < grid.height) : (y += 1) {
        var x: usize = 0;
        while (x < grid.width) : (x += 1) {
            const pos = Pos{ .x = @intCast(x), .y = @intCast(y) };
            const value = grid.get(pos);
            var left: u8 = 0;
            var right: u8 = 0;
            switch (value) {
                '#' => {
                    left = '#';
                    right = '#';
                },
                'O' => {
                    left = '[';
                    right = ']';
                },
                '@' => {
                    left = '@';
                    right = '.';
                },
                else => continue,
            }
            const base = y * grid.width * 2 + x * 2;
            cells[base] = left;
            cells[base + 1] = right;
        }
    }
    return .{ .width = grid.width * 2, .height = grid.height, .cells = cells };
}

fn gps(grid: Grid, needle: u8) i32 {
    var result: i32 = 0;
    var y: usize = 0;
    while (y < grid.height) : (y += 1) {
        var x: usize = 0;
        while (x < grid.width) : (x += 1) {
            const pos = Pos{ .x = @intCast(x), .y = @intCast(y) };
            if (grid.get(pos) == needle) {
                result += 100 * @as(i32, @intCast(pos.y)) + @as(i32, @intCast(pos.x));
            }
        }
    }
    return result;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    const parsed = try parse(input, allocator);
    defer allocator.free(parsed.grid.cells);

    var grid1 = Grid{ .width = parsed.grid.width, .height = parsed.grid.height, .cells = try allocator.alloc(u8, parsed.grid.cells.len) };
    defer allocator.free(grid1.cells);
    @memcpy(grid1.cells, parsed.grid.cells);

    var position = find(grid1, '@');
    grid1.set(position, '.');
    for (parsed.moves) |b| {
        switch (b) {
            '<' => narrow(grid1, &position, LEFT),
            '>' => narrow(grid1, &position, RIGHT),
            '^' => narrow(grid1, &position, UP),
            'v' => narrow(grid1, &position, DOWN),
            else => {},
        }
    }
    const p1 = gps(grid1, 'O');

    var grid2 = try stretch(parsed.grid, allocator);
    defer allocator.free(grid2.cells);
    var position2 = find(grid2, '@');
    grid2.set(position2, '.');

    var todo: std.ArrayListUnmanaged(Pos) = .{};
    defer todo.deinit(allocator);

    for (parsed.moves) |b| {
        switch (b) {
            '<' => narrow(grid2, &position2, LEFT),
            '>' => narrow(grid2, &position2, RIGHT),
            '^' => wide(grid2, &position2, UP, &todo, allocator),
            'v' => wide(grid2, &position2, DOWN, &todo, allocator),
            else => {},
        }
    }
    const p2 = gps(grid2, '[');

    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, std.heap.page_allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
