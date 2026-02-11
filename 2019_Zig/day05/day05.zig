const std = @import("std");

const Result = struct {
    p1: i64,
    p2: i64,
};

fn run(V_input: []i64, input: i64) i64 {
    var V = V_input;
    var last_output: i64 = 0;
    var i: usize = 0;

    while (V[i] != 99) {
        const a = V[i + 1];
        const b = V[i + 2];
        const c = V[i + 3];

        switch (V[i]) {
            1 => { V[@intCast(c)] = V[@intCast(a)] + V[@intCast(b)]; i += 4; },
            101 => { V[@intCast(c)] = a + V[@intCast(b)]; i += 4; },
            1001 => { V[@intCast(c)] = V[@intCast(a)] + b; i += 4; },
            1101 => { V[@intCast(c)] = a + b; i += 4; },
            2 => { V[@intCast(c)] = V[@intCast(a)] * V[@intCast(b)]; i += 4; },
            102 => { V[@intCast(c)] = a * V[@intCast(b)]; i += 4; },
            1002 => { V[@intCast(c)] = V[@intCast(a)] * b; i += 4; },
            1102 => { V[@intCast(c)] = a * b; i += 4; },
            3 => { V[@intCast(a)] = input; i += 2; },
            4 => { last_output = V[@intCast(a)]; i += 2; },
            104 => { last_output = a; i += 2; },
            105 => { i = if (a != 0) @intCast(V[@intCast(b)]) else i + 3; },
            1005 => { i = if (V[@intCast(a)] != 0) @intCast(b) else i + 3; },
            1105 => { i = if (a != 0) @intCast(b) else i + 3; },
            106 => { i = if (a != 0) i + 3 else @intCast(V[@intCast(b)]); },
            1006 => { i = if (V[@intCast(a)] != 0) i + 3 else @intCast(b); },
            1106 => { i = if (a != 0) i + 3 else @intCast(b); },
            7 => { V[@intCast(c)] = if (V[@intCast(a)] < V[@intCast(b)]) 1 else 0; i += 4; },
            107 => { V[@intCast(c)] = if (a < V[@intCast(b)]) 1 else 0; i += 4; },
            1007 => { V[@intCast(c)] = if (V[@intCast(a)] < b) 1 else 0; i += 4; },
            1107 => { V[@intCast(c)] = if (a < b) 1 else 0; i += 4; },
            8 => { V[@intCast(c)] = if (V[@intCast(a)] == V[@intCast(b)]) 1 else 0; i += 4; },
            108 => { V[@intCast(c)] = if (a == V[@intCast(b)]) 1 else 0; i += 4; },
            1008 => { V[@intCast(c)] = if (V[@intCast(a)] == b) 1 else 0; i += 4; },
            1108 => { V[@intCast(c)] = if (a == b) 1 else 0; i += 4; },
            else => break,
        }
    }

    return last_output;
}

fn solve(input: []const u8) Result {
    var code: [5000]i64 = undefined;
    var code_len: usize = 0;

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
                code[code_len] = if (negative) -num else num;
                code_len += 1;
                num = 0;
                negative = false;
                in_number = false;
            }
        }
    }

    if (in_number) {
        code[code_len] = if (negative) -num else num;
        code_len += 1;
    }

    var V1: [5000]i64 = undefined;
    for (code, 0..) |v, idx| {
        V1[idx] = v;
    }
    const part1 = run(V1[0..code_len], 1);

    var V2: [5000]i64 = undefined;
    for (code, 0..) |v, idx| {
        V2[idx] = v;
    }
    const part2 = run(V2[0..code_len], 5);

    return Result{ .p1 = part1, .p2 = part2 };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    const start = std.time.microTimestamp();
    const result = solve(buffer);
    const end = std.time.microTimestamp();

    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {:.2} microseconds\n", .{@as(f64, @floatFromInt(end - start))});
}
