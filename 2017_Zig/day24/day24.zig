const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
const Component = struct { 
    a: u32, 
    b: u32,
    fn lessThan(_: void, lhs: Component, rhs: Component) bool {
        const lhs_same = @intFromBool(lhs.a == lhs.b);
        const rhs_same = @intFromBool(rhs.a == rhs.b);
        if (lhs_same != rhs_same) return lhs_same > rhs_same;
        return lhs.a < rhs.a;
    }
};
fn build(components: []const Component, used: u64, port: u32, strength: u32, length: u32, bridges: []u32) void {
    var found = false;
    for (components, 0..) |comp, i| {
        const mask: u64 = @as(u64, 1) << @intCast(i);
        if ((used & mask) != 0) continue;
        var next_port: u32 = undefined;
        var can_use = false;
        if (comp.a == port) {
            next_port = comp.b;
            can_use = true;
        } else if (comp.b == port) {
            next_port = comp.a;
            can_use = true;
        }
        if (can_use) {
            found = true;
            const new_used = used | mask;
            const new_strength = strength + comp.a + comp.b;
            const new_length = length + 1;
            build(components, new_used, next_port, new_strength, new_length, bridges);
            if (comp.a == comp.b) break;
        }
    }
    if (!found) {
        bridges[length] = @max(bridges[length], strength);
    }
}
fn solve(input: []const u8) Result {
    const gpa = std.heap.page_allocator;
    var components: std.ArrayList(Component) = .{};
    defer components.deinit(gpa);
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        var tokens = std.mem.tokenizeScalar(u8, line, '/');
        const a = std.fmt.parseInt(u32, tokens.next() orelse "0", 10) catch 0;
        const b = std.fmt.parseInt(u32, tokens.next() orelse "0", 10) catch 0;
        components.append(gpa, .{ .a = a, .b = b }) catch unreachable;
    }
    std.mem.sort(Component, components.items, {}, Component.lessThan);
    const bridges = gpa.alloc(u32, 64) catch unreachable;
    defer gpa.free(bridges);
    @memset(bridges, 0);
    build(components.items, 0, 0, 0, 0, bridges);
    var p1: u32 = 0;
    for (bridges) |strength| {
        p1 = @max(p1, strength);
    }
    var p2: u32 = 0;
    var i: usize = bridges.len;
    while (i > 0) {
        i -= 1;
        if (bridges[i] > 0) {
            p2 = bridges[i];
            break;
        }
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
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}