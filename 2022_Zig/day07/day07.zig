const std = @import("std");

const Result = struct {
    p1: u32,
    p2: u32,
};

fn isWhitespace(b: u8) bool {
    return b == ' ' or b == '\n' or b == '\r' or b == '\t';
}

fn solve(input: []const u8) Result {
    var stack = std.ArrayListUnmanaged(u32){};
    var sizes = std.ArrayListUnmanaged(u32){};
    defer {
        stack.deinit(std.heap.page_allocator);
        sizes.deinit(std.heap.page_allocator);
    }

    var cd_next = false;
    var total: u32 = 0;
    var i: usize = 0;

    while (i < input.len) {
        while (i < input.len and isWhitespace(input[i])) : (i += 1) {}
        if (i >= input.len) break;
        const start = i;
        while (i < input.len and !isWhitespace(input[i])) : (i += 1) {}
        const token = input[start..i];

        if (cd_next) {
            if (std.mem.eql(u8, token, "..")) {
                sizes.append(std.heap.page_allocator, total) catch unreachable;
                total += stack.pop().?;
            } else {
                stack.append(std.heap.page_allocator, total) catch unreachable;
                total = 0;
            }
            cd_next = false;
            continue;
        }

        if (std.mem.eql(u8, token, "cd")) {
            cd_next = true;
        } else if (token.len > 0 and token[0] >= '0' and token[0] <= '9') {
            total += std.fmt.parseInt(u32, token, 10) catch 0;
        }
    }

    while (stack.items.len > 0) {
        const prev = stack.pop().?;
        sizes.append(std.heap.page_allocator, total) catch unreachable;
        total += prev;
    }

    var p1: u32 = 0;
    for (sizes.items) |size| {
        if (size <= 100_000) p1 += size;
    }

    const root = sizes.items[sizes.items.len - 1];
    const needed: u32 = 30_000_000 - (70_000_000 - root);
    var p2: u32 = root;
    for (sizes.items) |size| {
        if (size >= needed and size < p2) p2 = size;
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
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
