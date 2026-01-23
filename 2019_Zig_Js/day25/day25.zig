const std = @import("std");

const Result = struct { p1: i64, p2: i64 };

const N_ITEMS = 8;

const M_SOUTH: u8 = 3;
const M_EAST: u8 = 5;
const M_WEST: u8 = 7;
const M_NORTH: u8 = 14;

const BACK = [_]u8{
    0, 0, 0, M_NORTH, 0, M_WEST, 0,       M_EAST,
    0, 0, 0, 0,       0, 0,      M_SOUTH, 0,
};

const MOVES = [_][]const u8{
    "", "", "", "south\n", "", "east\n", "",        "west\n",
    "", "", "", "",        "", "",       "north\n", "",
};

const AVOID = [_][]const u8{
    "infinite loop",
    "escape pod",
    "molten lava",
    "giant electromagnet",
    "photons",
};

const SEC_ROOM = "== Security Checkpoint ==";

const CPU = struct {
    mem: []i64,
    pc: usize = 0,
    rel_base: i64 = 0,
    output: i64 = 0,
    input_ptr: ?*i64 = null,
    allocator: std.mem.Allocator,

    const State = enum { Halt, Input, Output };

    fn init(allocator: std.mem.Allocator, code: []const i64) !CPU {
        var mem = try allocator.alloc(i64, code.len + 10000);
        @memcpy(mem[0..code.len], code);
        @memset(mem[code.len..], 0);
        return CPU{
            .mem = mem,
            .allocator = allocator,
        };
    }

    fn deinit(self: *CPU) void {
        self.allocator.free(self.mem);
    }

    fn val(self: *CPU, mode: i64, param: i64) i64 {
        return switch (mode) {
            0 => if (param >= 0 and param < self.mem.len) self.mem[@intCast(param)] else 0,
            1 => param,
            2 => if (self.rel_base + param >= 0 and self.rel_base + param < self.mem.len)
                self.mem[@intCast(self.rel_base + param)]
            else
                0,
            else => 0,
        };
    }

    fn addr(self: *CPU, mode: i64, param: i64) usize {
        return @intCast(if (mode == 2) self.rel_base + param else param);
    }

    fn run(self: *CPU) State {
        while (true) {
            if (self.pc >= self.mem.len) return .Halt;

            const op = self.mem[self.pc];
            const opcode = @mod(op, 100);
            const m1 = @mod(@divFloor(op, 100), 10);
            const m2 = @mod(@divFloor(op, 1000), 10);
            const m3 = @mod(@divFloor(op, 10000), 10);

            const a = self.mem[self.pc + 1];
            const b = if (self.pc + 2 < self.mem.len) self.mem[self.pc + 2] else 0;
            const c = if (self.pc + 3 < self.mem.len) self.mem[self.pc + 3] else 0;

            switch (opcode) {
                1 => {
                    const idx = self.addr(m3, c);
                    if (idx < self.mem.len) self.mem[idx] = self.val(m1, a) + self.val(m2, b);
                    self.pc += 4;
                },
                2 => {
                    const idx = self.addr(m3, c);
                    if (idx < self.mem.len) self.mem[idx] = self.val(m1, a) * self.val(m2, b);
                    self.pc += 4;
                },
                3 => {
                    const idx = self.addr(m1, a);
                    if (idx < self.mem.len) self.input_ptr = &self.mem[idx];
                    self.pc += 2;
                    return .Input;
                },
                4 => {
                    self.output = self.val(m1, a);
                    self.pc += 2;
                    return .Output;
                },
                5 => {
                    if (self.val(m1, a) != 0) {
                        self.pc = @intCast(self.val(m2, b));
                    } else {
                        self.pc += 3;
                    }
                },
                6 => {
                    if (self.val(m1, a) == 0) {
                        self.pc = @intCast(self.val(m2, b));
                    } else {
                        self.pc += 3;
                    }
                },
                7 => {
                    const idx = self.addr(m3, c);
                    if (idx < self.mem.len) self.mem[idx] = if (self.val(m1, a) < self.val(m2, b)) 1 else 0;
                    self.pc += 4;
                },
                8 => {
                    const idx = self.addr(m3, c);
                    if (idx < self.mem.len) self.mem[idx] = if (self.val(m1, a) == self.val(m2, b)) 1 else 0;
                    self.pc += 4;
                },
                9 => {
                    self.rel_base += self.val(m1, a);
                    self.pc += 2;
                },
                99 => {
                    return .Halt;
                },
                else => {
                    std.debug.print("Unknown opcode: {} at pc={}\n", .{ op, self.pc });
                    return .Halt;
                },
            }
        }
    }
};

const Solver = struct {
    cpu: *CPU,
    inventory: std.ArrayList([]const u8),
    sec_path: std.ArrayList(usize),
    goal_room: usize = 0,
    keycode: i64 = 0,
    allocator: std.mem.Allocator,

    fn init(cpu: *CPU, allocator: std.mem.Allocator) !Solver {
        return Solver{
            .cpu = cpu,
            .inventory = try std.ArrayList([]const u8).initCapacity(allocator, 10),
            .sec_path = try std.ArrayList(usize).initCapacity(allocator, 50),
            .allocator = allocator,
        };
    }

    fn deinit(self: *Solver) void {
        for (self.inventory.items) |item| self.allocator.free(item);
        self.inventory.deinit(self.allocator);
        self.sec_path.deinit(self.allocator);
    }

    fn send(self: *Solver, s: []const u8) void {
        for (s) |ch| {
            while (self.cpu.run() != .Input) {}
            self.cpu.input_ptr.?.* = ch;
        }
    }

    fn recv(self: *Solver, line: *std.ArrayList(u8)) !void {
        line.clearRetainingCapacity();
        while (self.cpu.run() == .Output) {
            const ch: u8 = @intCast(self.cpu.output);
            if (ch == '\n') {
                if (line.items.len == 0) continue;
                return;
            }
            try line.append(ch);
        }
    }

    fn take(self: *Solver, item: []const u8) !void {
        var cmd = try std.ArrayList(u8).initCapacity(self.allocator, 100);
        defer cmd.deinit(self.allocator);
        try cmd.appendSlice(self.allocator, "take ");
        try cmd.appendSlice(self.allocator, item);
        try cmd.append(self.allocator, '\n');
        self.send(cmd.items);

        while (self.cpu.run() == .Output) {}
    }

    fn drop(self: *Solver, item: []const u8) !void {
        var cmd = try std.ArrayList(u8).initCapacity(self.allocator, 100);
        defer cmd.deinit(self.allocator);
        try cmd.appendSlice(self.allocator, "drop ");
        try cmd.appendSlice(self.allocator, item);
        try cmd.append(self.allocator, '\n');
        self.send(cmd.items);

        while (self.cpu.run() == .Output) {}
    }

    fn parseRoom(self: *Solver) !struct { name: []const u8, exits: []const []const u8, items: []const []const u8 } {
        var lines = try std.ArrayList([]const u8).initCapacity(self.allocator, 50);
        defer {
            for (lines.items) |line| self.allocator.free(line);
            lines.deinit(self.allocator);
        }

        var line_buf = try std.ArrayList(u8).initCapacity(self.allocator, 200);
        defer line_buf.deinit(self.allocator);

        var state: CPU.State = .Output;
        while (state != .Input and state != .Halt) {
            line_buf.clearRetainingCapacity();

            while (true) {
                state = self.cpu.run();
                if (state != .Output) break;
                const ch: u8 = @intCast(self.cpu.output);
                if (ch == '\n') break;
                try line_buf.append(self.allocator, ch);
            }
            if (line_buf.items.len > 0) {
                try lines.append(self.allocator, try self.allocator.dupe(u8, line_buf.items));
            }
        }

        var room_name: []const u8 = "";
        var exits = try std.ArrayList([]const u8).initCapacity(self.allocator, 10);
        var items = try std.ArrayList([]const u8).initCapacity(self.allocator, 10);

        for (lines.items) |line| {
            if (std.mem.indexOf(u8, line, "==") != null) {
                room_name = try self.allocator.dupe(u8, line);
            } else if (std.mem.startsWith(u8, line, "- ")) {
                const item = line[2..];

                var is_dir = false;
                for (MOVES) |move| {
                    if (move.len > 0) {
                        const dir = move[0 .. move.len - 1];
                        if (std.mem.eql(u8, item, dir)) {
                            try exits.append(self.allocator, try self.allocator.dupe(u8, item));
                            is_dir = true;
                            break;
                        }
                    }
                }
                if (!is_dir) {
                    try items.append(self.allocator, try self.allocator.dupe(u8, item));
                }
            }
        }

        return .{
            .name = room_name,
            .exits = try exits.toOwnedSlice(self.allocator),
            .items = try items.toOwnedSlice(self.allocator),
        };
    }

    fn collectItems(self: *Solver, back: usize, missing: *usize, parent_sec: bool) !struct { missing: usize, sec: bool } {
        const room = try self.parseRoom();
        defer {
            self.allocator.free(room.name);
            for (room.exits) |exit| self.allocator.free(exit);
            self.allocator.free(room.exits);
            for (room.items) |item| self.allocator.free(item);
            self.allocator.free(room.items);
        }

        if (std.mem.indexOf(u8, room.name, SEC_ROOM) != null) {
            var exit_bits: u32 = 0;
            for (room.exits) |exit| {
                if (std.mem.eql(u8, exit, "north")) exit_bits |= @as(u32, 1) << M_NORTH;
                if (std.mem.eql(u8, exit, "south")) exit_bits |= @as(u32, 1) << M_SOUTH;
                if (std.mem.eql(u8, exit, "east")) exit_bits |= @as(u32, 1) << M_EAST;
                if (std.mem.eql(u8, exit, "west")) exit_bits |= @as(u32, 1) << M_WEST;
            }
            const goal_bits = exit_bits ^ @as(u32, @intCast(back));
            if (goal_bits != 0) {
                self.goal_room = @ctz(goal_bits);
            }
            return .{ .missing = missing.*, .sec = true };
        }

        for (room.items) |item| {
            var is_dangerous = false;
            for (AVOID) |avoid| {
                if (std.mem.eql(u8, item, avoid)) {
                    is_dangerous = true;
                    break;
                }
            }
            if (!is_dangerous) {
                try self.take(item);
                try self.inventory.append(self.allocator, try self.allocator.dupe(u8, item));
                missing.* -= 1;
            }
        }

        if (missing.* == 0 and parent_sec) {
            return .{ .missing = 0, .sec = false };
        }

        var child_sec = false;

        var exit_bits: u32 = 0;
        for (room.exits) |exit| {
            if (std.mem.eql(u8, exit, "north")) exit_bits |= @as(u32, 1) << M_NORTH;
            if (std.mem.eql(u8, exit, "south")) exit_bits |= @as(u32, 1) << M_SOUTH;
            if (std.mem.eql(u8, exit, "east")) exit_bits |= @as(u32, 1) << M_EAST;
            if (std.mem.eql(u8, exit, "west")) exit_bits |= @as(u32, 1) << M_WEST;
        }

        var ex = exit_bits ^ @as(u32, @intCast(back));
        while (ex != 0) {
            const d = @ctz(ex);
            ex &= ex - 1;
            const b = BACK[d];

            self.send(MOVES[d]);

            const result = try self.collectItems(@as(usize, 1) << @intCast(b), missing, child_sec or parent_sec);
            missing.* = result.missing;

            if (missing.* == 0 and result.sec) {
                return .{ .missing = 0, .sec = true };
            } else if (result.sec) {
                try self.sec_path.append(self.allocator, d);
                child_sec = true;
            }

            self.send(MOVES[b]);

            if (missing.* == 0 and (child_sec or parent_sec)) {
                break;
            }
        }

        return .{ .missing = missing.*, .sec = child_sec };
    }

    fn reverseDir(dir: []const u8) []const u8 {
        if (std.mem.eql(u8, dir, "north")) return "south";
        if (std.mem.eql(u8, dir, "south")) return "north";
        if (std.mem.eql(u8, dir, "east")) return "west";
        if (std.mem.eql(u8, dir, "west")) return "east";
        return "";
    }

    fn tryWeight(self: *Solver, direction: []const u8) !?i64 {
        self.send(direction);

        var response = try std.ArrayList(u8).initCapacity(self.allocator, 5000);
        defer response.deinit(self.allocator);

        while (self.cpu.run() == .Output) {
            try response.append(self.allocator, @intCast(self.cpu.output));
        }

        if (std.mem.indexOf(u8, response.items, "lighter") != null) {
            return -1;
        } else if (std.mem.indexOf(u8, response.items, "heavier") != null) {
            return 1;
        } else {
            var max_num: i64 = 0;
            var current_num: i64 = 0;
            var in_number = false;

            for (response.items) |c| {
                if (c >= '0' and c <= '9') {
                    current_num = current_num * 10 + (c - '0');
                    in_number = true;
                } else {
                    if (in_number and current_num > max_num) {
                        max_num = current_num;
                    }
                    current_num = 0;
                    in_number = false;
                }
            }

            if (in_number and current_num > max_num) {
                max_num = current_num;
            }

            return max_num;
        }
    }

    fn run(self: *Solver) !i64 {
        var missing: usize = N_ITEMS;
        _ = try self.collectItems(0, &missing, false);

        if (self.inventory.items.len == 0) {
            return 0;
        }

        var i: usize = self.sec_path.items.len;
        while (i > 0) {
            i -= 1;
            const dir = self.sec_path.items[i];
            self.send(MOVES[dir]);

            while (self.cpu.run() == .Output) {}
        }

        const goal_direction = MOVES[self.goal_room];

        for (self.inventory.items) |item| {
            try self.drop(item);
        }

        const num_items = self.inventory.items.len;
        const combinations: usize = @as(usize, 1) << @intCast(num_items);

        var combo: usize = 0;
        while (combo < combinations) : (combo += 1) {
            var idx: usize = 0;
            while (idx < num_items) : (idx += 1) {
                const should_have = (combo & (@as(usize, 1) << @intCast(idx))) != 0;
                if (should_have) {
                    try self.take(self.inventory.items[idx]);
                }
            }

            if (try self.tryWeight(goal_direction)) |result| {
                if (result > 100) {
                    return result;
                }
            }

            idx = 0;
            while (idx < num_items) : (idx += 1) {
                const was_held = (combo & (@as(usize, 1) << @intCast(idx))) != 0;
                if (was_held) {
                    try self.drop(self.inventory.items[idx]);
                }
            }
        }

        return 0;
    }
};

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var code = try std.ArrayList(i64).initCapacity(allocator, 5000);
    defer code.deinit(allocator);

    var num: i64 = 0;
    var neg = false;
    var has_num = false;
    for (input) |c| {
        if (c == '-') {
            neg = true;
            has_num = true;
        } else if (c >= '0' and c <= '9') {
            num = num * 10 + (c - '0');
            has_num = true;
        } else if (c == ',' or c == '\n' or c == '\r') {
            if (has_num) {
                try code.append(allocator, if (neg) -num else num);
                num = 0;
                neg = false;
                has_num = false;
            }
        }
    }
    if (has_num) try code.append(allocator, if (neg) -num else num);

    var cpu = try CPU.init(allocator, code.items);
    defer cpu.deinit();

    var solver = try Solver.init(&cpu, allocator);
    defer solver.deinit();

    const result = try solver.run();

    return Result{ .p1 = result, .p2 = 0 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, arena.allocator());
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\nPart 2: {}\nTime: {d:.2} microseconds\n", .{ result.p1, result.p2, elapsed_us });
}
