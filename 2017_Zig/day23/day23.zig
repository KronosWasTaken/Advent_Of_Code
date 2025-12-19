const std = @import("std");
const Result = struct { p1: i64, p2: i64 };
fn getValue(registers: *std.AutoHashMap(u8, i64), operand: []const u8) i64 {
    if (operand.len == 0) return 0;
    if (operand[0] >= 'a' and operand[0] <= 'z') {
        return registers.get(operand[0]) orelse 0;
    }
    return std.fmt.parseInt(i64, operand, 10) catch 0;
}
fn solve(input: []const u8) Result {
    const gpa = std.heap.page_allocator;
    var instructions: std.ArrayList([]const u8) = .{};
    defer instructions.deinit(gpa);
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        instructions.append(gpa, line) catch unreachable;
    }
    var registers = std.AutoHashMap(u8, i64).init(gpa);
    defer registers.deinit();
    var mul_count: i64 = 0;
    var pc: isize = 0;
    while (pc >= 0 and pc < instructions.items.len) {
        const inst = instructions.items[@intCast(pc)];
        var tokens = std.mem.tokenizeScalar(u8, inst, ' ');
        const op = tokens.next() orelse "";
        const x = tokens.next() orelse "";
        const y = tokens.next() orelse "";
        if (std.mem.eql(u8, op, "set")) {
            registers.put(x[0], getValue(&registers, y)) catch unreachable;
        } else if (std.mem.eql(u8, op, "sub")) {
            const current = registers.get(x[0]) orelse 0;
            registers.put(x[0], current - getValue(&registers, y)) catch unreachable;
        } else if (std.mem.eql(u8, op, "mul")) {
            mul_count += 1;
            const current = registers.get(x[0]) orelse 0;
            registers.put(x[0], current * getValue(&registers, y)) catch unreachable;
        } else if (std.mem.eql(u8, op, "jnz")) {
            if (getValue(&registers, x) != 0) {
                pc += getValue(&registers, y);
                continue;
            }
        }
        pc += 1;
    }
    const p1 = mul_count;
    var first_num: i64 = 0;
    var lines2 = std.mem.tokenizeAny(u8, input, "\r\n");
    if (lines2.next()) |first_line| {
        var tokens = std.mem.tokenizeScalar(u8, first_line, ' ');
        _ = tokens.next(); 
        _ = tokens.next(); 
        if (tokens.next()) |num_str| {
            first_num = std.fmt.parseInt(i64, num_str, 10) catch 0;
        }
    }
    var b: i64 = 100000 + 100 * first_num;
    const c: i64 = b + 17000;
    var h: i64 = 0;
    while (b <= c) : (b += 17) {
        var is_composite = false;
        if (@mod(b, 2) == 0) {
            is_composite = true;
        } else {
            var d: i64 = 3;
            while (d * d <= b) : (d += 2) {
                if (@mod(b, d) == 0) {
                    is_composite = true;
                    break;
                }
            }
        }
        if (is_composite) h += 1;
    }
    return .{ .p1 = p1, .p2 = h };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}