const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
const Vec3 = struct {
    x: i64,
    y: i64,
    z: i64,
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
inline fn manhattan(v: Vec3) u64 {
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
    const exists = gpa.alloc(bool, n) catch unreachable;
    defer gpa.free(exists);
    @memset(exists, true);
    const particles2 = gpa.alloc(Particle, n) catch unreachable;
    defer gpa.free(particles2);
    @memcpy(particles2, particles.items);
    var positions = std.AutoHashMap(u64, u32).init(gpa);
    defer positions.deinit();
    var collided = std.AutoHashMap(u32, void).init(gpa);
    defer collided.deinit();
    for (0..40) |_| {
        positions.clearRetainingCapacity();
        collided.clearRetainingCapacity();
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
        for (particles2, 0..) |particle, i| {
            if (!exists[i]) continue;
            const hash = @as(u64, @bitCast(particle.p.x)) ^
                        (@as(u64, @bitCast(particle.p.y)) << 21) ^
                        (@as(u64, @bitCast(particle.p.z)) << 42);
            if (positions.get(hash)) |j| {
                collided.put(@intCast(i), {}) catch unreachable;
                collided.put(j, {}) catch unreachable;
            } else {
                positions.put(hash, @intCast(i)) catch unreachable;
            }
        }
        var iter = collided.keyIterator();
        while (iter.next()) |idx| {
            exists[idx.*] = false;
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
