const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

const Bus = struct {
    offset: u64,
    id: u64,
};

fn solve(input: []const u8) Result {
    var timestamp: u64 = 0;
    var i: usize = 0;
    while (i < input.len and input[i] >= '0') : (i += 1) {
        timestamp = timestamp * 10 + (input[i] - '0');
    }
    while (i < input.len and (input[i] == '\n' or input[i] == '\r')) : (i += 1) {}

    var buses = std.ArrayListUnmanaged(Bus){};
    defer buses.deinit(std.heap.page_allocator);

    var offset: u64 = 0;
    while (i < input.len) {
        if (input[i] == 'x') {
            i += 1;
            if (i < input.len and input[i] == ',') i += 1;
            offset += 1;
            continue;
        }
        if (input[i] < '0' or input[i] > '9') {
            i += 1;
            continue;
        }
        var id: u64 = 0;
        while (i < input.len and input[i] >= '0') : (i += 1) {
            id = id * 10 + (input[i] - '0');
        }
        buses.append(std.heap.page_allocator, .{ .offset = offset, .id = id }) catch unreachable;
        if (i < input.len and input[i] == ',') i += 1;
        offset += 1;
    }

    var best_wait: u64 = std.math.maxInt(u64);
    var best_id: u64 = 0;
    for (buses.items) |bus| {
        const wait = bus.id - (timestamp % bus.id);
        if (wait < best_wait) {
            best_wait = wait;
            best_id = bus.id;
        }
    }
    const part1 = best_id * best_wait;

    var time: u64 = 0;
    var step: u64 = buses.items[0].id;
    var idx: usize = 1;
    while (idx < buses.items.len) : (idx += 1) {
        const bus = buses.items[idx];
        const remainder = (bus.id - (bus.offset % bus.id)) % bus.id;
        while (time % bus.id != remainder) {
            time += step;
        }
        step *= bus.id;
    }

    return .{ .p1 = part1, .p2 = time };
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
