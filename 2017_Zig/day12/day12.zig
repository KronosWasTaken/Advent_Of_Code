const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
const UnionFind = struct {
    parent: []usize,
    rank: []u32,
    fn init(allocator: std.mem.Allocator, size: usize) !UnionFind {
        const parent = try allocator.alloc(usize, size);
        const rank = try allocator.alloc(u32, size);
        for (0..size) |i| {
            parent[i] = i;
            rank[i] = 0;
        }
        return .{ .parent = parent, .rank = rank };
    }
    fn deinit(self: *UnionFind, allocator: std.mem.Allocator) void {
        allocator.free(self.parent);
        allocator.free(self.rank);
    }
    fn find(self: *UnionFind, x: usize) usize {
        if (self.parent[x] != x) {
            self.parent[x] = self.find(self.parent[x]);
        }
        return self.parent[x];
    }
    fn unite(self: *UnionFind, x: usize, y: usize) void {
        const root_x = self.find(x);
        const root_y = self.find(y);
        if (root_x != root_y) {
            if (self.rank[root_x] < self.rank[root_y]) {
                self.parent[root_x] = root_y;
            } else {
                self.parent[root_y] = root_x;
                if (self.rank[root_x] == self.rank[root_y]) {
                    self.rank[root_x] += 1;
                }
            }
        }
    }
};
fn solve(input: []const u8) Result {
    const gpa = std.heap.page_allocator;
    var uf = UnionFind.init(gpa, 2048) catch unreachable;
    defer uf.deinit(gpa);
    var parent: usize = 0;
    var n: usize = 0;
    var have_number = false;
    var max: usize = 0;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            n = n * 10 + (c - '0');
            have_number = true;
        } else {
            if (have_number) {
                if (n > max) max = n;
                if (parent > 0) {
                    uf.unite(parent, n);
                } else {
                    parent = n;
                }
                have_number = false;
                n = 0;
            }
            if (c == '\n') {
                parent = 0;
            }
        }
    }
    const group_zero = uf.find(0);
    var part1: u32 = 0;
    var part2: u32 = 0;
    for (0..max + 1) |i| {
        const root = uf.find(i);
        if (root == group_zero) part1 += 1;
        if (root == i) part2 += 1;
    }
    return .{ .p1 = part1, .p2 = part2 };
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
