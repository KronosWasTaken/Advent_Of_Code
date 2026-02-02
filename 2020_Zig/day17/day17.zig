const std = @import("std");

const Result = struct {
    p1: usize,
    p2: usize,
};

fn Position(comptime D: usize) type {
    return [D]isize;
}

fn Cells(comptime D: usize) type {
    return std.AutoHashMap(Position(D), void);
}

fn Space(comptime D: usize) type {
    return struct {
        allocator: std.mem.Allocator,
        cells: Cells(D),

        const Self = @This();

        fn init(input: Input) !Self {
            var cells = Cells(D).init(input.allocator);

            for (input.initial, 0..) |row, i| {
                for (row, 0..) |active, j| {
                    if (active) {
                        var position: Position(D) = [_]isize{0} ** D;
                        position[0] = @intCast(i);
                        position[1] = @intCast(j);

                        try cells.put(position, {});
                    }
                }
            }

            return Self{ .allocator = input.allocator, .cells = cells };
        }

        fn deinit(self: *Self) void {
            self.cells.deinit();
        }

        fn updateCell(next: *Cells(D), position: Position(D), active: bool, neighbours: usize) !void {
            if (active) {
                if (neighbours == 3 or neighbours == 4) {
                    try next.put(position, {});
                }
            } else if (neighbours == 3) {
                try next.put(position, {});
            }
        }

        fn countNeighbours(self: Self, position: Position(D)) usize {
            const NeighbourCounter = struct {
                cells: Cells(D),
                neighbours: usize = 0,

                fn apply(s: *@This(), neighbour: Position(D)) void {
                    if (s.cells.contains(neighbour)) s.neighbours += 1;
                }
            };

            var counter = NeighbourCounter{ .cells = self.cells };
            forEachNeighbour(position, &counter);
            return counter.neighbours;
        }

        fn forEachNeighbour(position: Position(D), func: anytype) void {
            const max: usize = comptime std.math.pow(usize, 3, D);
            comptime var i: usize = 0;
            inline while (i < max) : (i += 1) {
                var neighbour: Position(D) = [_]isize{0} ** D;
                comptime var d: usize = 0;
                inline while (d < D) : (d += 1) {
                    const offset = (i / std.math.pow(usize, 3, d)) % 3;
                    neighbour[d] = position[d] + @as(isize, @intCast(offset)) - 1;
                }
                func.apply(neighbour);
            }
        }

        fn getToVisit(self: *Self) !Cells(D) {
            var to_visit = Cells(D).init(self.allocator);
            errdefer to_visit.deinit();

            var iterator = self.cells.iterator();
            while (iterator.next()) |entry| {
                const position = entry.key_ptr.*;
                const NeighbourVisit = struct {
                    to_visit: Cells(D),

                    fn apply(s: *@This(), neighbour: Position(D)) void {
                        s.to_visit.put(neighbour, {}) catch unreachable;
                    }
                };

                var visit = NeighbourVisit{ .to_visit = to_visit };
                forEachNeighbour(position, &visit);
                to_visit = visit.to_visit;
            }

            return to_visit;
        }

        fn step(self: *Self) !void {
            var to_visit = try self.getToVisit();
            defer to_visit.deinit();

            var next = Cells(D).init(self.allocator);
            var visit = to_visit.iterator();
            while (visit.next()) |entry| {
                const position = entry.key_ptr.*;
                const active = self.cells.contains(position);
                const neighbours = self.countNeighbours(position);
                try updateCell(&next, position, active, neighbours);
            }

            self.cells.deinit();
            self.cells = next;
        }

        fn stepN(self: *Self, n: usize) !void {
            var i: usize = 0;
            while (i < n) : (i += 1) {
                try self.step();
            }
        }

        fn countCells(self: Self) usize {
            return self.cells.count();
        }
    };
}

const Input = struct {
    allocator: std.mem.Allocator,
    initial: [][]bool,

    fn init(allocator: std.mem.Allocator, initial: [][]bool) Input {
        return Input{ .allocator = allocator, .initial = initial };
    }

    fn deinit(self: Input) void {
        for (self.initial) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.initial);
    }
};

fn parseInput(allocator: std.mem.Allocator, input: []const u8) !Input {
    var initial = std.ArrayListUnmanaged([]bool){};
    errdefer initial.deinit(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line_raw| {
        const line = if (line_raw.len > 0 and line_raw[line_raw.len - 1] == '\r')
            line_raw[0 .. line_raw.len - 1]
        else
            line_raw;
        var row = std.ArrayListUnmanaged(bool){};
        errdefer row.deinit(allocator);

        for (line) |char| {
            try row.append(allocator, char == '#');
        }

        try initial.append(allocator, try row.toOwnedSlice(allocator));
    }

    return Input.init(allocator, try initial.toOwnedSlice(allocator));
}

fn solve(input_data: []const u8) Result {
    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    var input = parseInput(alloc.allocator(), input_data) catch unreachable;
    defer input.deinit();

    var space3 = Space(3).init(input) catch unreachable;
    defer space3.deinit();
    space3.stepN(6) catch unreachable;
    const p1 = space3.countCells();

    var space4 = Space(4).init(input) catch unreachable;
    defer space4.deinit();
    space4.stepN(6) catch unreachable;
    const p2 = space4.countCells();

    return .{ .p1 = p1, .p2 = p2 };
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
