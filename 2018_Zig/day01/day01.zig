const std = @import("std");

const Result = struct { p1: i32, p2: i32 };

const Value = struct {
    a: i32, 
    b: i32, 
    c: i32, 
};

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var v = std.ArrayList(Value).initCapacity(allocator, 1000) catch unreachable;
    
    
    var n: i32 = 0;
    var total: i32 = 0;
    var neg: u1 = 0;
    
    for (input) |c| {
        const digit = c -% '0';
        if (digit < 10) {
            n = 10 * n + digit;
            continue;
        }
        neg |= @intFromBool(c == '-');
        if (n != 0) {
            
            total += n - @as(i32, neg) ^ -@as(i32, neg);
            v.append(allocator, .{ .a = total, .b = 0, .c = @intCast(v.items.len) }) catch unreachable;
            n = 0;
            neg = 0;
        }
    }
    
    const part1 = v.items[v.items.len - 1].a;
    
    
    for (v.items) |*val| {
        val.b = @divTrunc(val.a, part1);
        val.a = @rem(val.a, part1);
        if (val.a < 0) {
            val.a += part1;
            val.b -= 1;
        }
    }
    
    
    std.mem.sort(Value, v.items, {}, struct {
        fn lessThan(_: void, a: Value, b: Value) bool {
            return if (a.a == b.a) a.b < b.b else a.a < b.a;
        }
    }.lessThan);
    
    
    var last = Value{ .a = -1, .b = 0, .c = 0 };
    for (v.items) |*val| {
        const tmp = if (val.a == last.a)
            Value{ .a = val.b - last.b, .b = @intCast(last.c), .c = val.a + val.b * part1 }
        else
            Value{ .a = std.math.maxInt(i32), .b = std.math.maxInt(i32), .c = std.math.maxInt(i32) };
        last = val.*;
        val.* = tmp;
    }
    
    
    std.mem.sort(Value, v.items, {}, struct {
        fn lessThan(_: void, a: Value, b: Value) bool {
            return if (a.a == b.a) a.b < b.b else a.a < b.a;
        }
    }.lessThan);
    
    return Result{ .p1 = part1, .p2 = v.items[0].c };
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
