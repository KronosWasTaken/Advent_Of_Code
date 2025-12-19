const std = @import("std");
const Result = struct { p1: i32, p2: i32 };
fn solve(input: []const u8) Result {
    var registers = std.StringHashMap(i32).init(std.heap.page_allocator);
    defer registers.deinit();
    var p2: i32 = 0;
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        var tokens = std.mem.tokenizeAny(u8, trimmed, " \t");
        const reg_a = tokens.next() orelse continue;
        const op = tokens.next() orelse continue;
        const val_c = tokens.next() orelse continue;
        _ = tokens.next(); 
        const reg_e = tokens.next() orelse continue;
        const cmp = tokens.next() orelse continue;
        const val_g = tokens.next() orelse continue;
        const first = registers.get(reg_e) orelse 0;
        const second = std.fmt.parseInt(i32, val_g, 10) catch continue;
        const predicate = blk: {
            if (std.mem.eql(u8, cmp, "==")) break :blk first == second;
            if (std.mem.eql(u8, cmp, "!=")) break :blk first != second;
            if (std.mem.eql(u8, cmp, ">=")) break :blk first >= second;
            if (std.mem.eql(u8, cmp, "<=")) break :blk first <= second;
            if (std.mem.eql(u8, cmp, ">")) break :blk first > second;
            if (std.mem.eql(u8, cmp, "<")) break :blk first < second;
            break :blk false;
        };
        if (predicate) {
            const current = registers.get(reg_a) orelse 0;
            const fourth = std.fmt.parseInt(i32, val_c, 10) catch continue;
            const new_val = if (std.mem.eql(u8, op, "inc"))
                current + fourth
            else
                current - fourth;
            registers.put(reg_a, new_val) catch unreachable;
            p2 = @max(p2, new_val);
        }
    }
    var p1: i32 = 0;
    var iter = registers.valueIterator();
    while (iter.next()) |val| {
        p1 = @max(p1, val.*);
    }
    return .{ .p1 = p1, .p2 = p2 };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var total: u64 = 0;
    const iterations = 1000;
    var result: Result = undefined;
    for (0..iterations) |_| {
        var timer = try std.time.Timer.start();
        result = solve(input);
        total += timer.read();
    }
    const avg_ns = total / iterations;
    const avg_us = @as(f64, @floatFromInt(avg_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{avg_us});
}
