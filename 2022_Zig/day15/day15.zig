const std = @import("std");

const Point = struct {
    x: i32,
    y: i32,

    fn manhattan(self: Point, other: Point) i32 {
        const dx = @as(i32, @intCast(@abs(self.x - other.x)));
        const dy = @as(i32, @intCast(@abs(self.y - other.y)));
        return dx + dy;
    }
};

const Input = struct {
    sensor: Point,
    beacon: Point,
    manhattan: i32,
};

const Range = struct { start: i32, end: i32 };

const Result = struct {
    p1: i32,
    p2: u64,
};

fn parseNumbers(line: []const u8, out: []i32) usize {
    var count: usize = 0;
    var value: i32 = 0;
    var sign: i32 = 1;
    var in_number = false;
    for (line) |b| {
        if (b == '-') {
            sign = -1;
        } else if (b >= '0' and b <= '9') {
            value = value * 10 + @as(i32, b - '0');
            in_number = true;
        } else if (in_number) {
            out[count] = value * sign;
            count += 1;
            value = 0;
            sign = 1;
            in_number = false;
        }
    }
    if (in_number) {
        out[count] = value * sign;
        count += 1;
    }
    return count;
}

fn parse(input: []const u8, allocator: std.mem.Allocator) ![]Input {
    var lines = std.ArrayListUnmanaged([]const u8){};
    defer lines.deinit(allocator);

    var start: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        const b = input[i];
        var newline_len: usize = 0;
        if (b == '\r') {
            newline_len = if (i + 1 < input.len and input[i + 1] == '\n') 2 else 1;
        } else if (b == '\n') {
            newline_len = 1;
        }
        if (newline_len > 0) {
            if (i > start) lines.append(allocator, input[start..i]) catch unreachable;
            start = i + newline_len;
            i += newline_len;
            continue;
        }
        i += 1;
    }
    if (start < input.len) lines.append(allocator, input[start..]) catch unreachable;

    var inputs = try allocator.alloc(Input, lines.items.len);
    var idx: usize = 0;
    for (lines.items) |line| {
        var buffer: [8]i32 = undefined;
        _ = parseNumbers(line, &buffer);
        const sensor = Point{ .x = buffer[0], .y = buffer[1] };
        const beacon = Point{ .x = buffer[2], .y = buffer[3] };
        inputs[idx] = .{ .sensor = sensor, .beacon = beacon, .manhattan = sensor.manhattan(beacon) };
        idx += 1;
    }

    return inputs[0..idx];
}

fn part1(inputs: []const Input, row: i32, allocator: std.mem.Allocator) i32 {
    var ranges = std.ArrayListUnmanaged(Range){};
    defer ranges.deinit(allocator);
    var beacons = std.ArrayListUnmanaged(i32){};
    defer beacons.deinit(allocator);

    for (inputs) |input| {
        const extra = input.manhattan - @as(i32, @intCast(@abs(input.sensor.y - row)));
        if (extra >= 0) {
            ranges.append(allocator, .{ .start = input.sensor.x - extra, .end = input.sensor.x + extra }) catch unreachable;
        }
        if (input.beacon.y == row) {
            beacons.append(allocator, input.beacon.x) catch unreachable;
        }
    }

    std.sort.heap(Range, ranges.items, {}, struct {
        fn lessThan(_: void, a: Range, b: Range) bool {
            return a.start < b.start;
        }
    }.lessThan);

    var total: i32 = 0;
    var max: i32 = std.math.minInt(i32);
    for (ranges.items) |range| {
        if (range.start > max) {
            total += range.end - range.start + 1;
            max = range.end;
        } else {
            const extra = range.end - max;
            if (extra > 0) total += extra;
            if (range.end > max) max = range.end;
        }
    }

    if (beacons.items.len > 0) {
        std.sort.heap(i32, beacons.items, {}, struct {
            fn lessThan(_: void, a: i32, b: i32) bool {
                return a < b;
            }
        }.lessThan);
        var unique: i32 = 1;
        var i: usize = 1;
        while (i < beacons.items.len) : (i += 1) {
            if (beacons.items[i] != beacons.items[i - 1]) unique += 1;
        }
        total -= unique;
    }

    return total;
}

fn part2(inputs: []const Input, size: i32, allocator: std.mem.Allocator) u64 {
    var top = std.ArrayListUnmanaged(i32){};
    var left = std.ArrayListUnmanaged(i32){};
    var bottom = std.ArrayListUnmanaged(i32){};
    var right = std.ArrayListUnmanaged(i32){};
    defer {
        top.deinit(allocator);
        left.deinit(allocator);
        bottom.deinit(allocator);
        right.deinit(allocator);
    }

    for (inputs) |input| {
        top.append(allocator, input.sensor.x + input.sensor.y - input.manhattan - 1) catch unreachable;
        left.append(allocator, input.sensor.x - input.sensor.y - input.manhattan - 1) catch unreachable;
        bottom.append(allocator, input.sensor.x + input.sensor.y + input.manhattan + 1) catch unreachable;
        right.append(allocator, input.sensor.x - input.sensor.y + input.manhattan + 1) catch unreachable;
    }

    std.sort.heap(i32, top.items, {}, struct {
        fn lessThan(_: void, a: i32, b: i32) bool {
            return a < b;
        }
    }.lessThan);
    std.sort.heap(i32, left.items, {}, struct {
        fn lessThan(_: void, a: i32, b: i32) bool {
            return a < b;
        }
    }.lessThan);
    std.sort.heap(i32, bottom.items, {}, struct {
        fn lessThan(_: void, a: i32, b: i32) bool {
            return a < b;
        }
    }.lessThan);
    std.sort.heap(i32, right.items, {}, struct {
        fn lessThan(_: void, a: i32, b: i32) bool {
            return a < b;
        }
    }.lessThan);

    var horizontal = std.ArrayListUnmanaged(i32){};
    var vertical = std.ArrayListUnmanaged(i32){};
    defer {
        horizontal.deinit(allocator);
        vertical.deinit(allocator);
    }

    var i: usize = 0;
    var j: usize = 0;
    while (i < top.items.len and j < bottom.items.len) {
        const a = top.items[i];
        const b = bottom.items[j];
        if (a == b) {
            horizontal.append(allocator, a) catch unreachable;
            i += 1;
            j += 1;
        } else if (a < b) {
            i += 1;
        } else {
            j += 1;
        }
    }

    i = 0;
    j = 0;
    while (i < left.items.len and j < right.items.len) {
        const a = left.items[i];
        const b = right.items[j];
        if (a == b) {
            vertical.append(allocator, a) catch unreachable;
            i += 1;
            j += 1;
        } else if (a < b) {
            i += 1;
        } else {
            j += 1;
        }
    }

    for (vertical.items) |x| {
        for (horizontal.items) |y| {
            const px = @divTrunc(x + y, 2);
            const py = @divTrunc(y - x, 2);
            if (px < 0 or py < 0 or px > size or py > size) continue;
            var ok = true;
            for (inputs) |input| {
                if (input.sensor.manhattan(.{ .x = px, .y = py }) <= input.manhattan) {
                    ok = false;
                    break;
                }
            }
            if (ok) return 4_000_000 * @as(u64, @intCast(px)) + @as(u64, @intCast(py));
        }
    }

    return 0;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const inputs = parse(input, allocator) catch unreachable;
    defer allocator.free(inputs);
    return .{ .p1 = part1(inputs, 2_000_000, allocator), .p2 = part2(inputs, 4_000_000, allocator) };
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
