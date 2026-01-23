const std = @import("std");

pub fn Computer(comptime max_input: usize, comptime max_mem: usize) type {
    _ = max_input;
    return struct {
        mem: [max_mem]i64,
        pc: usize = 0,
        rel_base: i64 = 0,
        inputs: [2]i64 = undefined,
        input_write_idx: usize = 0,
        input_read_idx: usize = 0,
        last_output: i64 = 0,
        halted: bool = false,

        const Self = @This();

        pub fn init(_: std.mem.Allocator, code: []const i64) Self {
            var self: Self = undefined;
            @memset(&self.mem, 0);
            @memcpy(self.mem[0..code.len], code);
            self.pc = 0;
            self.rel_base = 0;
            self.last_output = 0;
            self.halted = false;
            self.input_write_idx = 0;
            self.input_read_idx = 0;
            return self;
        }

        pub fn deinit(_: *Self) void {
        }

        pub fn addInput(self: *Self, val: i64) void {
            if (self.input_write_idx < 2) {
                self.inputs[self.input_write_idx] = val;
                self.input_write_idx += 1;
            }
        }

        fn fetchVal(self: *Self, mode: i64, param: i64) i64 {
            return switch (mode) {
                0 => self.mem[@intCast(param)],
                1 => param,
                2 => self.mem[@intCast(self.rel_base + param)],
                else => 0,
            };
        }

        fn storeVal(self: *Self, mode: i64, addr: i64, val: i64) void {
            const idx: usize = switch (mode) {
                0 => @intCast(addr),
                2 => @intCast(self.rel_base + addr),
                else => @intCast(addr),
            };
            self.mem[idx] = val;
        }

        pub const State = enum { Running, Output, Input, Halted };

        pub fn run(self: *Self) State {
            while (!self.halted) {
                const op = self.mem[self.pc];
                const opcode = @mod(op, 100);
                const m1 = @mod(@divFloor(op, 100), 10);
                const m2 = @mod(@divFloor(op, 1000), 10);
                const m3 = @mod(@divFloor(op, 10000), 10);

                switch (opcode) {
                    1 => {
                        const p1 = self.fetchVal(m1, self.mem[self.pc + 1]);
                        const p2 = self.fetchVal(m2, self.mem[self.pc + 2]);
                        self.storeVal(m3, self.mem[self.pc + 3], p1 + p2);
                        self.pc += 4;
                    },
                    2 => {
                        const p1 = self.fetchVal(m1, self.mem[self.pc + 1]);
                        const p2 = self.fetchVal(m2, self.mem[self.pc + 2]);
                        self.storeVal(m3, self.mem[self.pc + 3], p1 * p2);
                        self.pc += 4;
                    },
                    3 => {
                        if (self.input_read_idx >= self.input_write_idx) {
                            return .Input;
                        }
                        const val = self.inputs[self.input_read_idx];
                        self.input_read_idx += 1;
                        self.storeVal(m1, self.mem[self.pc + 1], val);
                        self.pc += 2;
                    },
                    4 => {
                        self.last_output = self.fetchVal(m1, self.mem[self.pc + 1]);
                        self.pc += 2;
                        return .Output;
                    },
                    5 => {
                        const p1 = self.fetchVal(m1, self.mem[self.pc + 1]);
                        const p2 = self.fetchVal(m2, self.mem[self.pc + 2]);
                        self.pc = if (p1 != 0) @intCast(p2) else self.pc + 3;
                    },
                    6 => {
                        const p1 = self.fetchVal(m1, self.mem[self.pc + 1]);
                        const p2 = self.fetchVal(m2, self.mem[self.pc + 2]);
                        self.pc = if (p1 == 0) @intCast(p2) else self.pc + 3;
                    },
                    7 => {
                        const p1 = self.fetchVal(m1, self.mem[self.pc + 1]);
                        const p2 = self.fetchVal(m2, self.mem[self.pc + 2]);
                        self.storeVal(m3, self.mem[self.pc + 3], if (p1 < p2) 1 else 0);
                        self.pc += 4;
                    },
                    8 => {
                        const p1 = self.fetchVal(m1, self.mem[self.pc + 1]);
                        const p2 = self.fetchVal(m2, self.mem[self.pc + 2]);
                        self.storeVal(m3, self.mem[self.pc + 3], if (p1 == p2) 1 else 0);
                        self.pc += 4;
                    },
                    9 => {
                        const p1 = self.fetchVal(m1, self.mem[self.pc + 1]);
                        self.rel_base += p1;
                        self.pc += 2;
                    },
                    99 => {
                        self.halted = true;
                        return .Halted;
                    },
                    else => {
                        self.halted = true;
                        return .Halted;
                    },
                }
            }
            return .Halted;
        }
    };
}
