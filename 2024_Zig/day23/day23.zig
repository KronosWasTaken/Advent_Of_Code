const std = @import("std");

const Result = struct {
    p1: usize,
    p2: []const u8,
};

fn toIndex(bytes: []const u8) usize {
    return 26 * @as(usize, bytes[0] - 'a') + @as(usize, bytes[1] - 'a');
}

fn toChar(value: usize) u8 {
    return @as(u8, @intCast(value)) + 'a';
}

fn solve(input: []const u8) !Result {
    const allocator = std.heap.page_allocator;
    var nodes = std.AutoHashMap(usize, std.ArrayListUnmanaged(usize)).init(allocator);
    defer {
        var it = nodes.valueIterator();
        while (it.next()) |list| list.deinit(allocator);
        nodes.deinit();
    }

    var edges = try allocator.alloc(bool, 676 * 676);
    defer allocator.free(edges);
    @memset(edges, false);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |raw| {
        var line = raw;
        if (line.len > 0 and line[line.len - 1] == '\r') line = line[0 .. line.len - 1];
        if (line.len < 5) continue;
        const from = toIndex(line[0..2]);
        const to = toIndex(line[3..5]);
        const entry_from = try nodes.getOrPut(from);
        if (!entry_from.found_existing) entry_from.value_ptr.* = .{};
        try entry_from.value_ptr.append(allocator, to);
        const entry_to = try nodes.getOrPut(to);
        if (!entry_to.found_existing) entry_to.value_ptr.* = .{};
        try entry_to.value_ptr.append(allocator, from);
        edges[from * 676 + to] = true;
        edges[to * 676 + from] = true;
    }

    var seen = [_]bool{false} ** 676;
    var triangles: usize = 0;
    var n1: usize = 494;
    while (n1 < 520) : (n1 += 1) {
        if (nodes.get(n1)) |neighbours| {
            seen[n1] = true;
            var i: usize = 0;
            while (i < neighbours.items.len) : (i += 1) {
                const n2 = neighbours.items[i];
                var j: usize = i;
                while (j < neighbours.items.len) : (j += 1) {
                    const n3 = neighbours.items[j];
                    if (!seen[n2] and !seen[n3] and edges[n2 * 676 + n3]) triangles += 1;
                }
            }
        }
    }

    @memset(&seen, false);
    var clique = std.ArrayListUnmanaged(usize){};
    defer clique.deinit(allocator);
    var largest = std.ArrayListUnmanaged(usize){};
    defer largest.deinit(allocator);

    var it = nodes.iterator();
    while (it.next()) |entry| {
        const key = entry.key_ptr.*;
        if (seen[key]) continue;
        clique.clearRetainingCapacity();
        try clique.append(allocator, key);
        for (entry.value_ptr.items) |n2| {
            var ok = true;
            for (clique.items) |c| {
                if (!edges[n2 * 676 + c]) {
                    ok = false;
                    break;
                }
            }
            if (ok) {
                seen[n2] = true;
                try clique.append(allocator, n2);
            }
        }
        if (clique.items.len > largest.items.len) {
            try largest.resize(allocator, clique.items.len);
            @memcpy(largest.items, clique.items);
        }
    }

    std.mem.sort(usize, largest.items, {}, std.sort.asc(usize));
    var out = std.ArrayListUnmanaged(u8){};
    defer out.deinit(allocator);
    for (largest.items) |node| {
        try out.append(allocator, toChar(node / 26));
        try out.append(allocator, toChar(node % 26));
        try out.append(allocator, ',');
    }
    if (out.items.len > 0) _ = out.pop();

    const result = try allocator.alloc(u8, out.items.len);
    @memcpy(result, out.items);
    return .{ .p1 = triangles, .p2 = result };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {s}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
