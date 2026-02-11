const std = @import("std");

const EXTRA: usize = 3_000;

const Result = struct {
    p1: i32,
    p2: i64,
};

const State = union(enum) {
    Input,
    Output: i64,
    Halted,
};

const Point = struct {
    x: i32,
    y: i32,

    fn add(self: Point, other: Point) Point {
        return Point{ .x = self.x + other.x, .y = self.y + other.y };
    }

    fn clockwise(self: Point) Point {
        return if (self.eql(UP)) RIGHT else if (self.eql(RIGHT)) DOWN else if (self.eql(DOWN)) LEFT else UP;
    }

    fn counterClockwise(self: Point) Point {
        return if (self.eql(UP)) LEFT else if (self.eql(LEFT)) DOWN else if (self.eql(DOWN)) RIGHT else UP;
    }

    fn eql(self: Point, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }
};

const ORIGIN = Point{ .x = 0, .y = 0 };
const UP = Point{ .x = 0, .y = -1 };
const DOWN = Point{ .x = 0, .y = 1 };
const LEFT = Point{ .x = -1, .y = 0 };
const RIGHT = Point{ .x = 1, .y = 0 };
const ORTHOGONAL = [_]Point{ UP, DOWN, LEFT, RIGHT };

const Computer = struct {
    pc: usize = 0,
    base: i64 = 0,
    code: []i64,
    input_queue: std.ArrayListUnmanaged(i64) = .{},
    input_read_idx: usize = 0,
    allocator: std.mem.Allocator,

    const Self = @This();

    fn init(allocator: std.mem.Allocator, program: []const i64) Self {
        var code = allocator.alloc(i64, program.len + EXTRA) catch unreachable;
        @memcpy(code[0..program.len], program);
        @memset(code[program.len..], 0);

        return Self{
            .pc = 0,
            .base = 0,
            .code = code,
            .input_queue = .{},
            .input_read_idx = 0,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        self.input_queue.deinit(self.allocator);
        self.allocator.free(self.code);
    }

    fn ensureMemory(self: *Self, addr: usize) void {
        if (addr < self.code.len) return;
        const new_len = addr + 1 + EXTRA;
        const old_len = self.code.len;
        const resized = self.allocator.realloc(self.code, new_len) catch unreachable;
        self.code = resized;
        @memset(self.code[old_len..], 0);
    }

    fn input(self: *Self, value: i64) void {
        self.input_queue.append(self.allocator, value) catch unreachable;
    }

    fn inputAscii(self: *Self, ascii: []const u8) void {
        for (ascii) |byte| {
            self.input_queue.append(self.allocator, @as(i64, @intCast(byte))) catch unreachable;
        }
    }

    fn reset(self: *Self) void {
        self.pc = 0;
        self.base = 0;
        self.input_queue.clearRetainingCapacity();
        self.input_read_idx = 0;
    }

    fn popInput(self: *Self) ?i64 {
        if (self.input_read_idx >= self.input_queue.items.len) {
            return null;
        }
        const value = self.input_queue.items[self.input_read_idx];
        self.input_read_idx += 1;
        if (self.input_read_idx == self.input_queue.items.len) {
            self.input_queue.clearRetainingCapacity();
            self.input_read_idx = 0;
        }
        return value;
    }

    fn run(self: *Self) State {
        while (true) {
            const op = self.code[self.pc];

            switch (@mod(op, 100)) {
                1 => {
                    const first = self.address(@divFloor(op, 100), 1);
                    const second = self.address(@divFloor(op, 1000), 2);
                    const third = self.address(@divFloor(op, 10000), 3);
                    self.ensureMemory(third);
                    self.code[third] = self.code[first] +% self.code[second];
                    self.pc += 4;
                },
                2 => {
                    const first = self.address(@divFloor(op, 100), 1);
                    const second = self.address(@divFloor(op, 1000), 2);
                    const third = self.address(@divFloor(op, 10000), 3);
                    self.ensureMemory(third);
                    self.code[third] = self.code[first] *% self.code[second];
                    self.pc += 4;
                },
                3 => {
                    const value = self.popInput() orelse return .Input;
                    const first = self.address(@divFloor(op, 100), 1);
                    self.ensureMemory(first);
                    self.code[first] = value;
                    self.pc += 2;
                },
                4 => {
                    const first = self.address(@divFloor(op, 100), 1);
                    const value = self.code[first];
                    self.pc += 2;
                    return .{ .Output = value };
                },
                5 => {
                    const first = self.address(@divFloor(op, 100), 1);
                    const second = self.address(@divFloor(op, 1000), 2);
                    const value = self.code[first] == 0;
                    self.pc = if (value) self.pc + 3 else @as(usize, @intCast(self.code[second]));
                },
                6 => {
                    const first = self.address(@divFloor(op, 100), 1);
                    const second = self.address(@divFloor(op, 1000), 2);
                    const value = self.code[first] == 0;
                    self.pc = if (value) @as(usize, @intCast(self.code[second])) else self.pc + 3;
                },
                7 => {
                    const first = self.address(@divFloor(op, 100), 1);
                    const second = self.address(@divFloor(op, 1000), 2);
                    const third = self.address(@divFloor(op, 10000), 3);
                    self.ensureMemory(third);
                    const value = self.code[first] < self.code[second];
                    self.code[third] = @as(i64, @intFromBool(value));
                    self.pc += 4;
                },
                8 => {
                    const first = self.address(@divFloor(op, 100), 1);
                    const second = self.address(@divFloor(op, 1000), 2);
                    const third = self.address(@divFloor(op, 10000), 3);
                    self.ensureMemory(third);
                    const value = self.code[first] == self.code[second];
                    self.code[third] = @as(i64, @intFromBool(value));
                    self.pc += 4;
                },
                9 => {
                    const first = self.address(@divFloor(op, 100), 1);
                    self.base = self.base +% self.code[first];
                    self.pc += 2;
                },
                else => return .Halted,
            }
        }
    }

    fn address(self: *Self, mode: i64, offset: usize) usize {
        const index = self.pc + offset;
        return switch (@mod(mode, 10)) {
            0 => @as(usize, @intCast(self.code[index])),
            1 => index,
            2 => @as(usize, @intCast(self.base +% self.code[index])),
            else => unreachable,
        };
    }
};

const Input = struct {
    code: []i64,
    scaffold: std.AutoHashMap(Point, void),
    position: Point,
    direction: Point,

    fn deinit(self: *Input, allocator: std.mem.Allocator) void {
        allocator.free(self.code);
        self.scaffold.deinit();
    }
};

const Movement = struct {
    routine: std.ArrayListUnmanaged(u8) = .{},
    functions: [3]?[]const u8,
};

fn parse(input: []const u8, allocator: std.mem.Allocator) !Input {
    var numbers: std.ArrayListUnmanaged(i64) = .{};

    var num: i64 = 0;
    var negative = false;
    var in_number = false;

    for (input) |c| {
        if (c == '-') {
            negative = true;
            in_number = true;
        } else if (c >= '0' and c <= '9') {
            num = num * 10 + (c - '0');
            in_number = true;
        } else if (c == ',' or c == '\n' or c == '\r') {
            if (in_number) {
                try numbers.append(allocator, if (negative) -num else num);
                num = 0;
                negative = false;
                in_number = false;
            }
        }
    }

    if (in_number) {
        try numbers.append(allocator, if (negative) -num else num);
    }

    const code = try numbers.toOwnedSlice(allocator);

    var computer = Computer.init(allocator, code);
    defer computer.deinit();

    var x: i32 = 0;
    var y: i32 = 0;
    var scaffold = std.AutoHashMap(Point, void).init(allocator);
    var position = ORIGIN;
    var direction = ORIGIN;

    while (true) {
        switch (computer.run()) {
            .Output => |next| {
                switch (next) {
                    10 => {
                        y += 1;
                    },
                    35 => {
                        try scaffold.put(Point{ .x = x, .y = y }, {});
                    },
                    60 => {
                        position = Point{ .x = x, .y = y };
                        direction = LEFT;
                    },
                    62 => {
                        position = Point{ .x = x, .y = y };
                        direction = RIGHT;
                    },
                    94 => {
                        position = Point{ .x = x, .y = y };
                        direction = UP;
                    },
                    118 => {
                        position = Point{ .x = x, .y = y };
                        direction = DOWN;
                    },
                    else => {},
                }
                x = if (next == 10) 0 else x + 1;
            },
            else => break,
        }
    }

    return Input{ .code = code, .scaffold = scaffold, .position = position, .direction = direction };
}

fn part1(input: *const Input) i32 {
    var total: i32 = 0;
    var it = input.scaffold.keyIterator();

    while (it.next()) |point| {
        var is_intersection = true;
        for (ORTHOGONAL) |delta| {
            if (!input.scaffold.contains(point.add(delta))) {
                is_intersection = false;
                break;
            }
        }

        if (is_intersection) {
            total += point.x * point.y;
        }
    }

    return total;
}

fn part2(input: *const Input, allocator: std.mem.Allocator) !i64 {
    const path = try buildPath(input, allocator);
    defer allocator.free(path);

    var movement = Movement{ .functions = [3]?[]const u8{ null, null, null } };
    defer movement.routine.deinit(allocator);
    movement.routine.ensureUnusedCapacity(allocator, path.len) catch unreachable;

    _ = compress(path, &movement, allocator);

    var rules: std.ArrayListUnmanaged(u8) = .{};
    defer rules.deinit(allocator);

    const routine_slice = movement.routine.items;
    try appendRule(&rules, allocator, routine_slice);

    for (movement.functions) |maybe_fn| {
        if (maybe_fn) |func| {
            try appendRule(&rules, allocator, func);
        }
    }

    var modified = try allocator.alloc(i64, input.code.len);
    defer allocator.free(modified);
    @memcpy(modified, input.code);
    modified[0] = 2;

    var computer = Computer.init(allocator, modified);
    defer computer.deinit();
    computer.inputAscii(rules.items);

    return visit(&computer);
}

fn buildPath(input: *const Input, allocator: std.mem.Allocator) ![]u8 {
    const scaffold = &input.scaffold;
    var position = input.position;
    var direction = input.direction;
    var path: std.ArrayListUnmanaged(u8) = .{};

    while (true) {
        const left = direction.counterClockwise();
        const right = direction.clockwise();

        if (scaffold.contains(position.add(left))) {
            direction = left;
        } else if (scaffold.contains(position.add(right))) {
            direction = right;
        } else {
            break;
        }

        var next = position.add(direction);
        var magnitude: i32 = 0;

        while (scaffold.contains(next)) {
            position = next;
            next = next.add(direction);
            magnitude += 1;
        }

        const turn: u8 = if (direction.eql(left)) 'L' else 'R';
        var buffer: [32]u8 = undefined;
        const written = try std.fmt.bufPrint(&buffer, "{c},{d},", .{ turn, magnitude });
        try path.appendSlice(allocator, written);
    }

    return path.toOwnedSlice(allocator);
}

fn compress(path: []const u8, movement: *Movement, allocator: std.mem.Allocator) bool {
    if (path.len == 0) {
        return true;
    }
    if (movement.routine.items.len > 21) {
        return false;
    }

    const names = [_]u8{ 'A', 'B', 'C' };
    for (names, 0..) |name, i| {
        const start_len = movement.routine.items.len;
        movement.routine.append(allocator, name) catch unreachable;
        movement.routine.append(allocator, ',') catch unreachable;

        if (movement.functions[i]) |needle| {
            if (std.mem.startsWith(u8, path, needle)) {
                const remaining = path[needle.len..];
                if (compress(remaining, movement, allocator)) {
                    return true;
                }
            }
        } else {
            var segments_iter = Segments.init(path);
            while (segments_iter.next()) |segment| {
                movement.functions[i] = segment.needle;
                if (compress(segment.remaining, movement, allocator)) {
                    return true;
                }
                movement.functions[i] = null;
            }
        }

        movement.routine.items.len = start_len;
    }

    return false;
}

const Segments = struct {
    path: []const u8,
    indices: [32]usize,
    count: usize,
    cursor: usize,

    fn init(path: []const u8) Segments {
        var indices: [32]usize = undefined;
        var count: usize = 0;

        for (path, 0..) |b, i| {
            if (b == ',' and i < 21) {
                indices[count] = i;
                count += 1;
                if (count == indices.len) break;
            }
        }

        return Segments{ .path = path, .indices = indices, .count = count, .cursor = 1 };
    }

    fn next(self: *Segments) ?struct { needle: []const u8, remaining: []const u8 } {
        if (self.cursor >= self.count) {
            return null;
        }
        const idx = self.indices[self.cursor];
        self.cursor += 2;
        const split = idx + 1;
        return .{ .needle = self.path[0..split], .remaining = self.path[split..] };
    }
};

fn visit(computer: *Computer) i64 {
    computer.inputAscii("n\n");

    var result: i64 = 0;
    while (true) {
        switch (computer.run()) {
            .Output => |next| result = next,
            else => break,
        }
    }
    return result;
}

fn appendRule(rules: *std.ArrayListUnmanaged(u8), allocator: std.mem.Allocator, rule: []const u8) !void {
    try rules.appendSlice(allocator, rule);
    if (rules.items.len > 0 and rules.items[rules.items.len - 1] == ',') {
        rules.items[rules.items.len - 1] = '\n';
    } else {
        try rules.append(allocator, '\n');
    }
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var parsed = try parse(input, allocator);
    defer parsed.deinit(allocator);

    const p1 = part1(&parsed);
    const p2 = try part2(&parsed, allocator);

    return Result{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
