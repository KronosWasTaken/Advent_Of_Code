const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

const TRIANGLE = [_]usize{ 0, 0, 1, 3, 6, 10, 15, 21, 28, 36 };

fn update(checksum: usize, block: usize, index: usize, size: usize) struct { sum: usize, next: usize } {
    const id = index / 2;
    const extra = block * size + TRIANGLE[size];
    return .{ .sum = checksum + id * extra, .next = block + size };
}

fn part1(disk: []const usize) usize {
    var left: usize = 0;
    var right: usize = disk.len - 2 + disk.len % 2;
    var needed: usize = disk[right];
    var block: usize = 0;
    var checksum: usize = 0;

    while (left < right) {
        const res = update(checksum, block, left, disk[left]);
        checksum = res.sum;
        block = res.next;
        var available = disk[left + 1];
        left += 2;

        while (available > 0) {
            if (needed == 0) {
                if (left == right) break;
                right -= 2;
                needed = disk[right];
            }

            const size = if (needed < available) needed else available;
            const res2 = update(checksum, block, right, size);
            checksum = res2.sum;
            block = res2.next;
            available -= size;
            needed -= size;
        }
    }

    const res3 = update(checksum, block, right, needed);
    return res3.sum;
}

fn part2(disk: []const usize, allocator: std.mem.Allocator) !usize {
    var block: usize = 0;
    var checksum: usize = 0;
    var free: [10]std.ArrayListUnmanaged(usize) = undefined;
    for (&free) |*list| list.* = .{};
    defer for (&free) |*list| list.deinit(allocator);

    for (disk, 0..) |size, index| {
        if (index % 2 == 1 and size > 0) {
            try free[size].append(allocator, block);
        }
        block += size;
    }

    var free_len: usize = free.len;
    for (free[0..free_len]) |*heap| {
        try heap.append(allocator, block);
        std.mem.reverse(usize, heap.items);
    }

    var idx = disk.len;
    while (idx > 0) {
        idx -= 1;
        const size = disk[idx];
        block -= size;
        if (idx % 2 == 1) continue;

        var next_block = block;
        var next_index: usize = std.math.maxInt(usize);
        if (size < free_len) {
            var i = size;
            while (i < free_len) : (i += 1) {
                const heap = &free[i];
                const top = heap.items.len - 1;
                const first = heap.items[top];
                if (first < next_block) {
                    next_block = first;
                    next_index = i;
                }
            }
        }

        if (free_len > 0) {
            const biggest = free_len - 1;
            const top = free[biggest].items.len - 1;
            if (free[biggest].items[top] > block) {
                free_len -= 1;
            }
        }

        const id = idx / 2;
        const extra = next_block * size + TRIANGLE[size];
        checksum += id * extra;

        if (next_index != std.math.maxInt(usize)) {
            _ = free[next_index].pop();
            const to = next_index - size;
            if (to > 0) {
                var i = free[to].items.len;
                const value = next_block + size;
                while (free[to].items[i - 1] < value) : (i -= 1) {}
                try free[to].insert(allocator, i, value);
            }
        }
    }

    return checksum;
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !Result {
    var disk_list: std.ArrayListUnmanaged(usize) = .{};
    defer disk_list.deinit(allocator);

    for (input) |ch| {
        if (ch >= '0' and ch <= '9') {
            try disk_list.append(allocator, @intCast(ch - '0'));
        }
    }

    const disk = disk_list.items;
    const p1 = part1(disk);
    const p2 = try part2(disk, allocator);
    return .{ .p1 = @intCast(p1), .p2 = @intCast(p2) };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input, std.heap.page_allocator);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
