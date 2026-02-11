const std = @import("std");

const Result = struct { p1: i64, p2: i64 };
const N = 50;

const Computer = struct {
    mem: [3000]i64,
    ip: usize,
    rel_base: i64,
    output: i64,

    fn init(code: []const i64) Computer {
        var self: Computer = undefined;
        @memset(&self.mem, 0);
        @memcpy(self.mem[0..code.len], code);
        self.ip = 0;
        self.rel_base = 0;
        self.output = 0;
        return self;
    }

    fn getParam(self: *Computer, mode: i64, offset: usize) i64 {
        const param = self.mem[self.ip + offset];
        return switch (mode) {
            0 => self.mem[@intCast(param)],
            1 => param,
            2 => self.mem[@intCast(self.rel_base + param)],
            else => 0,
        };
    }

    fn setParam(self: *Computer, mode: i64, offset: usize, val: i64) void {
        const param = self.mem[self.ip + offset];
        const addr: usize = switch (mode) {
            0 => @intCast(param),
            2 => @intCast(self.rel_base + param),
            else => @intCast(param),
        };
        self.mem[addr] = val;
    }

    const State = enum { NeedInput, Output, Halted };

    fn run(self: *Computer) State {
        while (true) {
            const instr = self.mem[self.ip];
            const op = @mod(instr, 100);
            const m1 = @mod(@divFloor(instr, 100), 10);
            const m2 = @mod(@divFloor(instr, 1000), 10);
            const m3 = @mod(@divFloor(instr, 10000), 10);

            switch (op) {
                1 => {
                    const a = self.getParam(m1, 1);
                    const b = self.getParam(m2, 2);
                    self.setParam(m3, 3, a + b);
                    self.ip += 4;
                },
                2 => {
                    const a = self.getParam(m1, 1);
                    const b = self.getParam(m2, 2);
                    self.setParam(m3, 3, a * b);
                    self.ip += 4;
                },
                3 => {
                    return .NeedInput;
                },
                4 => {
                    self.output = self.getParam(m1, 1);
                    self.ip += 2;
                    return .Output;
                },
                5 => {
                    const a = self.getParam(m1, 1);
                    const b = self.getParam(m2, 2);
                    self.ip = if (a != 0) @intCast(b) else self.ip + 3;
                },
                6 => {
                    const a = self.getParam(m1, 1);
                    const b = self.getParam(m2, 2);
                    self.ip = if (a == 0) @intCast(b) else self.ip + 3;
                },
                7 => {
                    const a = self.getParam(m1, 1);
                    const b = self.getParam(m2, 2);
                    self.setParam(m3, 3, if (a < b) 1 else 0);
                    self.ip += 4;
                },
                8 => {
                    const a = self.getParam(m1, 1);
                    const b = self.getParam(m2, 2);
                    self.setParam(m3, 3, if (a == b) 1 else 0);
                    self.ip += 4;
                },
                9 => {
                    self.rel_base += self.getParam(m1, 1);
                    self.ip += 2;
                },
                99 => return .Halted,
                else => return .Halted,
            }
        }
    }

    fn provideInput(self: *Computer, val: i64) void {
        const last_instr = self.mem[self.ip];
        const m1 = @mod(@divFloor(last_instr, 100), 10);
        const param = self.mem[self.ip + 1];
        const addr: usize = switch (m1) {
            0 => @intCast(param),
            2 => @intCast(self.rel_base + param),
            else => @intCast(param),
        };
        self.mem[addr] = val;
        self.ip += 2;
    }
};

const Packet = struct { x: i64, y: i64 };

fn parseIntcode(input: []const u8) [3000]i64 {
    var code: [3000]i64 = undefined;
    @memset(&code, 0);
    var idx: usize = 0;

    var num: i64 = 0;
    var neg = false;
    var in_num = false;

    for (input) |c| {
        if (c == '-') {
            neg = true;
            in_num = true;
        } else if (c >= '0' and c <= '9') {
            num = num * 10 + (c - '0');
            in_num = true;
        } else if (c == ',' or c == '\n') {
            if (in_num) {
                code[idx] = if (neg) -num else num;
                idx += 1;
                num = 0;
                neg = false;
                in_num = false;
            }
        }
    }
    if (in_num) {
        code[idx] = if (neg) -num else num;
    }

    return code;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    const code = parseIntcode(input);

    var computers: [N]Computer = undefined;
    var queues: [N]std.ArrayList(Packet) = undefined;

    for (0..N) |i| {
        computers[i] = Computer.init(&code);
        queues[i] = try std.ArrayList(Packet).initCapacity(allocator, 100);

        _ = computers[i].run();
        computers[i].provideInput(@intCast(i));
    }
    defer for (0..N) |i| queues[i].deinit(allocator);

    var nat_packet: ?Packet = null;
    var part1: ?i64 = null;
    var last_nat_y: i64 = -1;

    while (true) {
        var idle = true;

        for (0..N) |i| {

            if (queues[i].items.len > 0) {
                idle = false;
                const p = queues[i].orderedRemove(0);
                _ = computers[i].run();
                computers[i].provideInput(p.x);
                _ = computers[i].run();
                computers[i].provideInput(p.y);
            } else {
                _ = computers[i].run();
                computers[i].provideInput(-1);
            }


            var state = computers[i].run();
            while (state == .Output) {
                const addr = computers[i].output;
                state = computers[i].run();
                if (state != .Output) break;
                const x = computers[i].output;
                state = computers[i].run();
                if (state != .Output) break;
                const y = computers[i].output;

                if (addr == 255) {
                    if (part1 == null) part1 = y;
                    nat_packet = Packet{ .x = x, .y = y };
                } else {
                    try queues[@intCast(addr)].append(allocator, Packet{ .x = x, .y = y });
                    idle = false;
                }

                state = computers[i].run();
            }
        }

        if (idle and nat_packet != null) {
            const p = nat_packet.?;
            if (p.y == last_nat_y) {
                return Result{ .p1 = part1.?, .p2 = p.y };
            }
            last_nat_y = p.y;
            try queues[0].append(allocator, p);
        }
    }
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
    std.debug.print("Part 1: {}\nPart 2: {}\nTime: {d:.2} microseconds\n", .{result.p1, result.p2, elapsed_us});
}
