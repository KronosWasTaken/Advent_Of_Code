const std = @import("std");

const Result = struct {
    p1: u64,
    p2: []const u8,
};

const Gate = struct {
    left: []const u8,
    kind: []const u8,
    right: []const u8,
    to: []const u8,
};

const Kind = enum(u8) { And, Or, Xor };

const OutputKey = struct {
    label: [3]u8,
    kind: Kind,
};

fn key3(s: []const u8) [3]u8 {
    return .{ s[0], s[1], s[2] };
}

fn toIndex(s: []const u8) usize {
    return (@as(usize, s[0] & 31) << 10) + (@as(usize, s[1] & 31) << 5) + @as(usize, s[2] & 31);
}

fn parseUnsigned(line: []const u8) u8 {
    var i: usize = 0;
    while (i < line.len and (line[i] < '0' or line[i] > '9')) : (i += 1) {}
    var value: u8 = 0;
    while (i < line.len and line[i] >= '0' and line[i] <= '9') : (i += 1) {
        value = value * 10 + @as(u8, line[i] - '0');
    }
    return value;
}

fn solve(input: []const u8) !Result {
    const allocator = std.heap.page_allocator;
    const sep = std.mem.indexOf(u8, input, "\r\n\r\n") orelse std.mem.indexOf(u8, input, "\n\n") orelse input.len;
    const prefix = input[0..sep];
    var suffix: []const u8 = "";
    if (sep < input.len) {
        const jump: usize = if (input[sep] == '\r') 4 else 2;
        if (sep + jump <= input.len) suffix = input[sep + jump ..];
    }

    var gates = std.ArrayListUnmanaged(Gate){};
    defer gates.deinit(allocator);
    var tokens = std.mem.tokenizeAny(u8, suffix, " \n\r\t");
    while (true) {
        const left = tokens.next() orelse break;
        const kind = tokens.next() orelse break;
        const right = tokens.next() orelse break;
        _ = tokens.next() orelse break;
        const to = tokens.next() orelse break;
        try gates.append(allocator, .{ .left = left, .kind = kind, .right = right, .to = to });
    }

    var queue = std.ArrayListUnmanaged(Gate){};
    defer queue.deinit(allocator);
    try queue.appendSlice(allocator, gates.items);

    var cache = try allocator.alloc(u8, 1 << 15);
    defer allocator.free(cache);
    @memset(cache, std.math.maxInt(u8));

    var line_it = std.mem.splitScalar(u8, prefix, '\n');
    while (line_it.next()) |raw| {
        var line = raw;
        if (line.len > 0 and line[line.len - 1] == '\r') line = line[0 .. line.len - 1];
        if (line.len < 6) continue;
        cache[toIndex(line[0..3])] = parseUnsigned(line[5..]);
    }

    var head: usize = 0;
    while (head < queue.items.len) : (head += 1) {
        const gate = queue.items[head];
        const left = cache[toIndex(gate.left)];
        const right = cache[toIndex(gate.right)];
        if (left == std.math.maxInt(u8) or right == std.math.maxInt(u8)) {
            try queue.append(allocator, gate);
            continue;
        }
        cache[toIndex(gate.to)] = switch (gate.kind[0]) {
            'A' => left & right,
            'O' => left | right,
            else => left ^ right,
        };
    }

    var result: u64 = 0;
    const start_idx = toIndex("z00");
    var i = toIndex("z46");
    while (true) {
        if (cache[i] != std.math.maxInt(u8)) result = (result << 1) | cache[i];
        if (i == start_idx) break;
        i -= 1;
    }

    var output = std.AutoHashMap(OutputKey, void).init(allocator);
    defer output.deinit();
    for (gates.items) |gate| {
        const kind = switch (gate.kind[0]) {
            'A' => Kind.And,
            'O' => Kind.Or,
            else => Kind.Xor,
        };
        try output.put(.{ .label = key3(gate.left), .kind = kind }, {});
        try output.put(.{ .label = key3(gate.right), .kind = kind }, {});
    }

    var swapped = std.StringHashMap(void).init(allocator);
    defer swapped.deinit();

    for (gates.items) |gate| {
        const kind = switch (gate.kind[0]) {
            'A' => Kind.And,
            'O' => Kind.Or,
            else => Kind.Xor,
        };
        switch (kind) {
            .And => {
                if (!std.mem.eql(u8, gate.left, "x00") and !std.mem.eql(u8, gate.right, "x00") and
                    !output.contains(.{ .label = key3(gate.to), .kind = .Or }))
                {
                    try swapped.put(gate.to, {});
                }
            },
            .Or => {
                if (gate.to[0] == 'z' and !std.mem.eql(u8, gate.to, "z45")) {
                    try swapped.put(gate.to, {});
                }
                if (output.contains(.{ .label = key3(gate.to), .kind = .Or })) {
                    try swapped.put(gate.to, {});
                }
            },
            .Xor => {
                if (gate.left[0] == 'x' or gate.right[0] == 'x') {
                    if (!std.mem.eql(u8, gate.left, "x00") and !std.mem.eql(u8, gate.right, "x00") and
                        !output.contains(.{ .label = key3(gate.to), .kind = .Xor }))
                    {
                        try swapped.put(gate.to, {});
                    }
                } else if (gate.to[0] != 'z') {
                    try swapped.put(gate.to, {});
                }
            },
        }
    }

    var keys = std.ArrayListUnmanaged([]const u8){};
    defer keys.deinit(allocator);
    var it = swapped.keyIterator();
    while (it.next()) |key| try keys.append(allocator, key.*);
    std.mem.sort([]const u8, keys.items, {}, struct {
        fn less(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.less);

    var out = std.ArrayListUnmanaged(u8){};
    defer out.deinit(allocator);
    for (keys.items) |key| {
        try out.appendSlice(allocator, key);
        try out.append(allocator, ',');
    }
    if (out.items.len > 0) _ = out.pop();
    const out_buf = try allocator.alloc(u8, out.items.len);
    @memcpy(out_buf, out.items);

    return .{ .p1 = result, .p2 = out_buf };
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
