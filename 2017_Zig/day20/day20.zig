const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
const Vec3 = struct {
    x: i64,
    y: i64,
    z: i64,
    pub fn eql(self: Vec3, other: Vec3) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }
    pub fn hash(self: Vec3, hasher: anytype) void {
        std.hash.autoHash(hasher, self.x);
        std.hash.autoHash(hasher, self.y);
        std.hash.autoHash(hasher, self.z);
    }
};
const Particle = struct {
    p: Vec3,
    v: Vec3,
    a: Vec3,
};
fn parseVec3(s: []const u8) Vec3 {
    var result = Vec3{ .x = 0, .y = 0, .z = 0 };
    const start = std.mem.indexOfScalar(u8, s, '<') orelse return result;
    const end = std.mem.indexOfScalar(u8, s, '>') orelse return result;
    var tokens = std.mem.tokenizeScalar(u8, s[start + 1 .. end], ',');
    if (tokens.next()) |t| result.x = std.fmt.parseInt(i64, t, 10) catch 0;
    if (tokens.next()) |t| result.y = std.fmt.parseInt(i64, t, 10) catch 0;
    if (tokens.next()) |t| result.z = std.fmt.parseInt(i64, t, 10) catch 0;
    return result;
}
fn manhattan(v: Vec3) u64 {
    const ax: u64 = @abs(v.x);
    const ay: u64 = @abs(v.y);
    const az: u64 = @abs(v.z);
    return ax + ay + az;
}
fn solve(input: []const u8) Result {
    const gpa = std.heap.page_allocator;
    var particles: std.ArrayList(Particle) = .{};
    defer particles.deinit(gpa);
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        const p_idx = std.mem.indexOf(u8, line, "p=") orelse continue;
        const v_idx = std.mem.indexOf(u8, line, "v=") orelse continue;
        const a_idx = std.mem.indexOf(u8, line, "a=") orelse continue;
        particles.append(gpa, .{
            .p = parseVec3(line[p_idx..]),
            .v = parseVec3(line[v_idx..]),
            .a = parseVec3(line[a_idx..]),
        }) catch unreachable;
    }
    var min_acc = manhattan(particles.items[0].a);
    var p1: u32 = 0;
    for (particles.items, 0..) |particle, i| {
        const acc = manhattan(particle.a);
        if (acc < min_acc) {
            min_acc = acc;
            p1 = @intCast(i);
        }
    }
    const n = particles.items.len;
    var exists = gpa.alloc(bool, n) catch unreachable;
    defer gpa.free(exists);
    @memset(exists, true);
    const particles2 = gpa.alloc(Particle, n) catch unreachable;
    defer gpa.free(particles2);
    @memcpy(particles2, particles.items);
    for (0..40) |_| {
        for (particles2, 0..) |*particle, i| {
            if (exists[i]) {
                particle.v.x += particle.a.x;
                particle.v.y += particle.a.y;
                particle.v.z += particle.a.z;
                particle.p.x += particle.v.x;
                particle.p.y += particle.v.y;
                particle.p.z += particle.v.z;
            }
        }
        for (0..n) |i| {
            if (!exists[i]) continue;
            for (i + 1..n) |j| {
                if (!exists[j]) continue;
                if (particles2[i].p.eql(particles2[j].p)) {
                    exists[i] = false;
                    exists[j] = false;
                }
            }
        }
    }
    var p2: u32 = 0;
    for (exists) |e| {
        if (e) p2 += 1;
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