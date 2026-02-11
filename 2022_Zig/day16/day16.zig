const std = @import("std");

const Input = struct {
    size: usize,
    aa: usize,
    all_valves: usize,
    flow: []u32,
    distance: []u32,
    closest: []u32,
};

const State = struct {
    todo: usize,
    from: usize,
    time: u32,
    pressure: u32,
};

const Result = struct {
    p1: u32,
    p2: u32,
};

const ValveInfo = struct {
    name: []const u8,
    flow: u32,
    edges: [][]const u8,
};

fn parseValves(input: []const u8, allocator: std.mem.Allocator) ![]ValveInfo {
    var lines = std.ArrayListUnmanaged([]const u8){};
    defer lines.deinit(allocator);

    var start: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        const b = input[i];
        if (b == '\r' or b == '\n') {
            if (i > start) try lines.append(allocator, input[start..i]);
            if (b == '\r' and i + 1 < input.len and input[i + 1] == '\n') i += 1;
            start = i + 1;
        }
        i += 1;
    }
    if (start < input.len) try lines.append(allocator, input[start..]);

    var valves = std.ArrayListUnmanaged(ValveInfo){};

    for (lines.items) |line| {
        var tokens: [32][]const u8 = undefined;
        var token_count: usize = 0;

        var in_token = false;
        var token_start: usize = 0;
        for (line, 0..) |ch, idx| {
            const is_token = (ch >= 'A' and ch <= 'Z') or (ch >= '0' and ch <= '9');
            if (is_token) {
                if (!in_token) {
                    token_start = idx;
                    in_token = true;
                }
            } else if (in_token) {
                tokens[token_count] = line[token_start..idx];
                token_count += 1;
                in_token = false;
            }
        }
        if (in_token) {
            tokens[token_count] = line[token_start..];
            token_count += 1;
        }

        const name = tokens[1];
        const flow = std.fmt.parseInt(u32, tokens[2], 10) catch 0;
        var edges = std.ArrayListUnmanaged([]const u8){};
        var idx: usize = 3;
        while (idx < token_count) : (idx += 1) {
            try edges.append(allocator, tokens[idx]);
        }

        try valves.append(allocator, .{ .name = name, .flow = flow, .edges = try edges.toOwnedSlice(allocator) });
    }

    return valves.toOwnedSlice(allocator);
}

fn parse(input: []const u8, allocator: std.mem.Allocator) !Input {
    const valves = try parseValves(input, allocator);
    defer {
        for (valves) |v| allocator.free(v.edges);
        allocator.free(valves);
    }

    var sorted = try allocator.dupe(ValveInfo, valves);
    std.sort.heap(ValveInfo, sorted, {}, struct {
        fn lessThan(_: void, a: ValveInfo, b: ValveInfo) bool {
            if (a.flow != b.flow) return a.flow > b.flow;
            return std.mem.lessThan(u8, a.name, b.name);
        }
    }.lessThan);

    var non_zero: usize = 0;
    for (sorted) |v| {
        if (v.flow > 0) non_zero += 1;
    }
    const size = non_zero + 1;

    var distance = try allocator.alloc(u32, size * size);
    @memset(distance, std.math.maxInt(u32));

    var indices = std.StringHashMap(usize).init(allocator);
    defer indices.deinit();
    for (sorted, 0..) |v, i| {
        try indices.put(v.name, i);
    }

    for (sorted[0..size], 0..) |valve, from| {
        distance[from * size + from] = 0;
        for (valve.edges) |edge| {
            var prev = valve.name;
            var cur = edge;
            var to = indices.get(cur).?;
            var total: u32 = 1;

            while (to >= size) {
                const next_valve = sorted[to];
                var found: []const u8 = "";
                for (next_valve.edges) |e| {
                    if (!std.mem.eql(u8, e, prev)) {
                        found = e;
                        break;
                    }
                }
                prev = cur;
                cur = found;
                to = indices.get(cur).?;
                total += 1;
            }
            distance[from * size + to] = total;
        }
    }

    for (0..size) |k| {
        for (0..size) |i| {
            for (0..size) |j| {
                const a = distance[i * size + k];
                const b = distance[k * size + j];
                const candidate = if (a == std.math.maxInt(u32) or b == std.math.maxInt(u32))
                    std.math.maxInt(u32)
                else
                    a + b;
                if (candidate < distance[i * size + j]) {
                    distance[i * size + j] = candidate;
                }
            }
        }
    }

    for (distance) |*d| {
        if (d.* != std.math.maxInt(u32)) d.* += 1;
    }

    const aa = size - 1;
    const all_valves = (@as(usize, 1) << @as(u6, @intCast(aa))) - 1;

    var flow = try allocator.alloc(u32, size);
    for (sorted[0..size], 0..) |v, i| flow[i] = v.flow;

    var closest = try allocator.alloc(u32, size);
    for (0..size) |i| {
        var min_dist: u32 = std.math.maxInt(u32);
        for (0..size) |j| {
            const d = distance[i * size + j];
            if (d > 1 and d < min_dist) min_dist = d;
        }
        closest[i] = if (min_dist == std.math.maxInt(u32)) 3 else min_dist;
    }

    return .{ .size = size, .aa = aa, .all_valves = all_valves, .flow = flow, .distance = distance, .closest = closest };
}

fn explore(input: *const Input, state: *const State, high_score: anytype) void {
    const score = high_score.call(state.todo, state.pressure);
    var todo = state.todo;
    while (todo > 0) {
        const to = @as(usize, @intCast(@ctz(todo)));
        todo ^= @as(usize, 1) << @as(u6, @intCast(to));

        const needed = input.distance[state.from * input.size + to];
        if (needed >= state.time) continue;

        const new_todo = state.todo ^ (@as(usize, 1) << @as(u6, @intCast(to)));
        const new_time = state.time - needed;
        const new_pressure = state.pressure + new_time * input.flow[to];

        var heuristic_todo = new_todo;
        var heuristic_time = new_time;
        var heuristic_pressure = new_pressure;
        while (heuristic_todo > 0 and heuristic_time > 3) {
            const h_to = @as(usize, @intCast(@ctz(heuristic_todo)));
            heuristic_todo ^= @as(usize, 1) << @as(u6, @intCast(h_to));
            heuristic_time -|= input.closest[h_to];
            heuristic_pressure += heuristic_time * input.flow[h_to];
        }

        if (heuristic_pressure > score) {
            const next = State{ .todo = new_todo, .from = to, .time = new_time, .pressure = new_pressure };
            explore(input, &next, high_score);
        }
    }
}

const HighScore1 = struct {
    score: *u32,
    fn call(self: *const @This(), _: usize, pressure: u32) u32 {
        self.score.* = @max(self.score.*, pressure);
        return self.score.*;
    }
};

const HighScore2Step1 = struct {
    you: *u32,
    remaining: *usize,
    fn call(self: *const @This(), todo: usize, pressure: u32) u32 {
        if (pressure > self.you.*) {
            self.you.* = pressure;
            self.remaining.* = todo;
        }
        return self.you.*;
    }
};

const HighScore2Step2 = struct {
    elephant: *u32,
    fn call(self: *const @This(), _: usize, pressure: u32) u32 {
        self.elephant.* = @max(self.elephant.*, pressure);
        return self.elephant.*;
    }
};

const HighScore2Step3 = struct {
    all_valves: usize,
    elephant: u32,
    score: []u32,
    fn call(self: *const @This(), todo: usize, pressure: u32) u32 {
        const done = self.all_valves ^ todo;
        self.score[done] = @max(self.score[done], pressure);
        return self.elephant;
    }
};

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const parsed = parse(input, allocator) catch unreachable;
    defer {
        allocator.free(parsed.flow);
        allocator.free(parsed.distance);
        allocator.free(parsed.closest);
    }

    var p1_score: u32 = 0;
    const hs1 = HighScore1{ .score = &p1_score };
    const start1 = State{ .todo = parsed.all_valves, .from = parsed.aa, .time = 30, .pressure = 0 };
    explore(&parsed, &start1, hs1);

    var you: u32 = 0;
    var remaining: usize = 0;
    const hs2_1 = HighScore2Step1{ .you = &you, .remaining = &remaining };
    const start2_1 = State{ .todo = parsed.all_valves, .from = parsed.aa, .time = 26, .pressure = 0 };
    explore(&parsed, &start2_1, hs2_1);

    var elephant: u32 = 0;
    const hs2_2 = HighScore2Step2{ .elephant = &elephant };
    const start2_2 = State{ .todo = remaining, .from = parsed.aa, .time = 26, .pressure = 0 };
    explore(&parsed, &start2_2, hs2_2);

    const score = allocator.alloc(u32, parsed.all_valves + 1) catch unreachable;
    defer allocator.free(score);
    @memset(score, 0);
    const hs2_3 = HighScore2Step3{ .all_valves = parsed.all_valves, .elephant = elephant, .score = score };
    const start2_3 = State{ .todo = parsed.all_valves, .from = parsed.aa, .time = 26, .pressure = 0 };
    explore(&parsed, &start2_3, hs2_3);

    var result = you + elephant;
    var candidates = std.ArrayListUnmanaged(struct { mask: usize, score: u32 }){};
    defer candidates.deinit(allocator);
    for (score, 0..) |s, i| {
        if (s > 0) candidates.append(allocator, .{ .mask = i, .score = s }) catch unreachable;
    }
    std.sort.heap(@TypeOf(candidates.items[0]), candidates.items, {}, struct {
        fn lessThan(_: void, a: @TypeOf(candidates.items[0]), b: @TypeOf(candidates.items[0])) bool {
            return a.score < b.score;
        }
    }.lessThan);

    var i = candidates.items.len;
    while (i > 1) {
        i -= 1;
        const c1 = candidates.items[i];
        if (c1.score * 2 <= result) break;
        var j = i;
        while (j > 0) {
            j -= 1;
            const c2 = candidates.items[j];
            if (c1.mask & c2.mask == 0) {
                result = @max(result, c1.score + c2.score);
                break;
            }
        }
    }

    return .{ .p1 = p1_score, .p2 = result };
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
