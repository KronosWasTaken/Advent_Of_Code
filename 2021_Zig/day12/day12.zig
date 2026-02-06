const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

const START: usize = 0;
const END: usize = 1;

const Input = struct {
    small: u32,
    edges: []u32,
};

const State = struct {
    from: usize,
    visited: u32,
    twice: bool,
};

fn parse(input: []const u8, allocator: std.mem.Allocator) Input {
    var token_count: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        while (i < input.len and !std.ascii.isAlphabetic(input[i])) : (i += 1) {}
        const start = i;
        while (i < input.len and std.ascii.isAlphabetic(input[i])) : (i += 1) {}
        if (start != i) token_count += 1;
    }

    const tokens = allocator.alloc([]const u8, token_count) catch unreachable;
    defer allocator.free(tokens);

    i = 0;
    var t: usize = 0;
    while (i < input.len) {
        while (i < input.len and !std.ascii.isAlphabetic(input[i])) : (i += 1) {}
        const start = i;
        while (i < input.len and std.ascii.isAlphabetic(input[i])) : (i += 1) {}
        if (start == i) break;
        tokens[t] = input[start..i];
        t += 1;
    }

    const names = allocator.alloc([]const u8, token_count) catch unreachable;
    defer allocator.free(names);
    const indices = allocator.alloc(usize, token_count) catch unreachable;
    defer allocator.free(indices);

    var name_count: usize = 0;
    var idx: usize = 0;
    while (idx < tokens.len) : (idx += 1) {
        const token = tokens[idx];
        var found: ?usize = null;
        var j: usize = 0;
        while (j < name_count) : (j += 1) {
            if (std.mem.eql(u8, names[j], token)) {
                found = j;
                break;
            }
        }
        if (found) |value| {
            indices[idx] = value;
        } else {
            const next_index = name_count;
            names[name_count] = token;
            name_count += 1;
            indices[idx] = next_index;
        }
    }

    var start_index: usize = 0;
    var end_index: usize = 0;
    var j: usize = 0;
    while (j < name_count) : (j += 1) {
        if (std.mem.eql(u8, names[j], "start")) start_index = j;
        if (std.mem.eql(u8, names[j], "end")) end_index = j;
    }

    const edges = allocator.alloc(u32, name_count) catch unreachable;
    @memset(edges, 0);

    idx = 0;
    while (idx + 1 < indices.len) : (idx += 2) {
        const a = indices[idx];
        const b = indices[idx + 1];
        edges[a] |= @as(u32, 1) << @as(u5, @intCast(b));
        edges[b] |= @as(u32, 1) << @as(u5, @intCast(a));
    }

    const not_start: u32 = ~(@as(u32, 1) << @as(u5, @intCast(start_index)));
    for (edges) |*edge| edge.* &= not_start;

    var small: u32 = 0;
    j = 0;
    while (j < name_count) : (j += 1) {
        if (std.ascii.isLower(names[j][0])) {
            small |= @as(u32, 1) << @as(u5, @intCast(j));
        }
    }

    if (start_index != START or end_index != END) {
        var remap = allocator.alloc(usize, name_count) catch unreachable;
        defer allocator.free(remap);
        j = 0;
        while (j < name_count) : (j += 1) remap[j] = j;
        remap[start_index] = START;
        remap[START] = start_index;
        remap[end_index] = END;
        remap[END] = end_index;

        var new_edges = allocator.alloc(u32, name_count) catch unreachable;
        @memset(new_edges, 0);
        j = 0;
        while (j < name_count) : (j += 1) {
            const from = remap[j];
            const mut = edges[j];
            var bits = mut;
            while (bits != 0) {
                const to = @ctz(bits);
                bits &= bits - 1;
                const remapped = remap[@as(usize, @intCast(to))];
                new_edges[from] |= @as(u32, 1) << @as(u5, @intCast(remapped));
            }
        }

        allocator.free(edges);
        var new_small: u32 = 0;
        j = 0;
        while (j < name_count) : (j += 1) {
            if (std.ascii.isLower(names[j][0])) {
                const mapped = remap[j];
                new_small |= @as(u32, 1) << @as(u5, @intCast(mapped));
            }
        }
        return .{ .small = new_small, .edges = new_edges };
    }

    return .{ .small = small, .edges = edges };
}

fn paths(input: Input, state: State, cache: []u32) u32 {
    const index = @as(usize, @intFromBool(state.twice)) + 2 * state.from + (input.edges.len * (state.visited / 2));
    if (cache[index] != 0) return cache[index];

    var caves = input.edges[state.from];
    var total: u32 = 0;
    const end_mask: u32 = @as(u32, 1) << @as(u5, END);
    if ((caves & end_mask) != 0) {
        caves ^= end_mask;
        total += 1;
    }

    while (caves != 0) {
        const to = @ctz(caves);
        caves &= caves - 1;
        const mask: u32 = @as(u32, 1) << @as(u5, @intCast(to));
        const once = (input.small & mask) == 0 or (state.visited & mask) == 0;
        if (once or state.twice) {
            const next = State{ .from = @as(usize, @intCast(to)), .visited = state.visited | mask, .twice = once and state.twice };
            total += paths(input, next, cache);
        }
    }

    cache[index] = total;
    return total;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const parsed = parse(input, allocator);
    defer allocator.free(parsed.edges);

    const shift: u5 = @as(u5, @intCast(parsed.edges.len - 2));
    const size = 2 * parsed.edges.len * (@as(usize, 1) << shift);
    const cache = allocator.alloc(u32, size) catch unreachable;
    defer allocator.free(cache);
    @memset(cache, 0);

    const start_state = State{ .from = START, .visited = 0, .twice = false };
    const p1 = paths(parsed, start_state, cache);

    @memset(cache, 0);
    const p2 = paths(parsed, State{ .from = START, .visited = 0, .twice = true }, cache);

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
