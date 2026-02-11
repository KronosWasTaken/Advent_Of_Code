const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

const Item = struct {
    label: []const u8,
    lens: u8,
};

fn hashByte(acc: u32, b: u8) u32 {
    return (acc + b) * 17 & 0xff;
}

fn labelEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    var i: usize = 0;
    while (i < a.len) : (i += 1) {
        if (a[i] != b[i]) return false;
    }
    return true;
}

pub fn solve(input: []const u8) Result {
    var boxes: [256]std.ArrayListUnmanaged(Item) = undefined;
    var i: usize = 0;
    while (i < boxes.len) : (i += 1) {
        boxes[i] = .{};
    }
    defer {
        i = 0;
        while (i < boxes.len) : (i += 1) {
            boxes[i].deinit(std.heap.page_allocator);
        }
    }

    var p1: u64 = 0;
    var p2: u64 = 0;

    var start: usize = 0;
    var idx: usize = 0;
    while (idx <= input.len) : (idx += 1) {
        if (idx == input.len or input[idx] == ',') {
            var end = idx;
            if (end > start and input[end - 1] == '\r') end -= 1;
            if (end == start) {
                start = idx + 1;
                continue;
            }

            var step_hash: u32 = 0;
            var label_hash: u32 = 0;
            var label_end: usize = start;
            var op: u8 = 0;
            var lens: u8 = 0;
            var j: usize = start;
            while (j < end) : (j += 1) {
                const b = input[j];
                step_hash = hashByte(step_hash, b);
                if (op == 0) {
                    if (b == '-' or b == '=') {
                        op = b;
                        label_end = j;
                        if (b == '=') lens = input[j + 1] - '0';
                    } else {
                        label_hash = hashByte(label_hash, b);
                    }
                }
            }

            p1 += step_hash;
            const label = input[start..label_end];
            const h: u8 = @intCast(label_hash);
            var slot = &boxes[h];

            if (op == '-') {
                var k: usize = 0;
                while (k < slot.items.len) : (k += 1) {
                    if (labelEql(slot.items[k].label, label)) {
                        const tail = slot.items.len - k - 1;
                        if (tail > 0) {
                            std.mem.copyForwards(Item, slot.items[k..], slot.items[k + 1 ..]);
                        }
                        slot.items.len -= 1;
                        break;
                    }
                }
            } else {
                var k: usize = 0;
                while (k < slot.items.len) : (k += 1) {
                    if (labelEql(slot.items[k].label, label)) {
                        slot.items[k].lens = lens;
                        break;
                    }
                }
                if (k == slot.items.len) {
                    slot.append(std.heap.page_allocator, .{ .label = label, .lens = lens }) catch return .{ .p1 = p1, .p2 = 0 };
                }
            }

            start = idx + 1;
        }
    }

    i = 0;
    while (i < boxes.len) : (i += 1) {
        const slot = boxes[i].items;
        var j: usize = 0;
        while (j < slot.len) : (j += 1) {
            p2 += @as(u64, i + 1) * @as(u64, j + 1) * slot[j].lens;
        }
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
