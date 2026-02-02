const std = @import("std");

const Result = struct {
    p1: i32,
    p2: i32,
};

const Instr = struct {
    op: u8,
    arg: i16,
};

const State = enum { Infinite, Halted };

fn execute(program: []const Instr, start_pc: i32, start_acc: i32, stamps: []u32, run_id: u32, main_visited: []bool) struct { state: State, acc: i32 } {
    var pc = start_pc;
    var acc = start_acc;
    while (true) {
        if (pc < 0 or pc >= @as(i32, @intCast(program.len))) return .{ .state = .Halted, .acc = acc };
        const idx = @as(usize, @intCast(pc));
        if (stamps[idx] == run_id or main_visited[idx]) return .{ .state = .Infinite, .acc = acc };
        stamps[idx] = run_id;

        const inst = program[idx];
        switch (inst.op) {
            'a' => {
                acc += inst.arg;
                pc += 1;
            },
            'j' => {
                pc += inst.arg;
            },
            else => {
                pc += 1;
            },
        }
    }
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var program = std.ArrayListUnmanaged(Instr){};
    errdefer program.deinit(arena.allocator());

    var i: usize = 0;
    while (i + 5 < input.len) {
        const op = input[i];
        const neg = input[i + 4] == '-';
        i += 5;

        var n: i16 = 0;
        while (i < input.len and input[i] >= '0') : (i += 1) {
            n = @intCast(n * 10 + @as(i16, input[i] - '0'));
        }
        if (neg) n = -n;

        if (i < input.len and input[i] == '\r') i += 1;
        if (i < input.len and input[i] == '\n') i += 1;

        program.append(arena.allocator(), .{ .op = op, .arg = n }) catch unreachable;
    }

    const stamps = arena.allocator().alloc(u32, program.items.len) catch unreachable;
    @memset(stamps, 0);
    const main_visited = arena.allocator().alloc(bool, program.items.len) catch unreachable;
    @memset(main_visited, false);

    var run_id: u32 = 1;
    var pc: i32 = 0;
    var acc: i32 = 0;
    var p1: i32 = 0;
    var p2: i32 = 0;

    while (true) {
        if (pc < 0 or pc >= @as(i32, @intCast(program.items.len))) {
            p2 = acc;
            break;
        }
        const idx = @as(usize, @intCast(pc));
        if (main_visited[idx]) {
            p1 = acc;
            break;
        }
        main_visited[idx] = true;

        const inst = program.items[idx];
        switch (inst.op) {
            'a' => {
                acc += inst.arg;
                pc += 1;
            },
            'j' => {
                const speculative = pc + 1;
                const result = execute(program.items, speculative, acc, stamps, run_id, main_visited);
                run_id += 1;
                if (result.state == .Halted) {
                    p2 = result.acc;
                }
                pc += inst.arg;
            },
            else => {
                const speculative = pc + inst.arg;
                const result = execute(program.items, speculative, acc, stamps, run_id, main_visited);
                run_id += 1;
                if (result.state == .Halted) {
                    p2 = result.acc;
                }
                pc += 1;
            },
        }
    }

    if (p1 == 0) {
        p1 = acc;
    }

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
