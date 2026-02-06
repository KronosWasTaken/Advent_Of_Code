const std = @import("std");

const Result = struct { p1: usize, p2: usize };

const A: usize = 0;
const B: usize = 1;
const C: usize = 2;
const D: usize = 3;
const ROOM: usize = 4;
const EMPTY: usize = 5;
const COST = [_]usize{ 1, 10, 100, 1000 };

fn absDiff(a: usize, b: usize) usize {
    return if (a >= b) a - b else b - a;
}

const Room = struct {
    data: u16,

    fn new(slots: [4]usize) Room {
        const packed_val = (1 << 12) | (slots[0] << 9) | (slots[1] << 6) | (slots[2] << 3) | slots[3];
        return .{ .data = @intCast(packed_val) };
    }

    fn size(self: Room) usize {
        return @as(usize, (15 - @clz(self.data)) / 3);
    }

    fn peek(self: Room) ?usize {
        return if (self.data > 1) @as(usize, self.data & 0b111) else null;
    }

    fn pop(self: *Room) usize {
        const pod = @as(usize, self.data & 0b111);
        self.data >>= 3;
        return pod;
    }

    fn open(self: Room, kind: usize) bool {
        return self.data == 1 or self.data == (1 << 3) + @as(u16, @intCast(kind)) or self.data == (1 << 6) + @as(u16, @intCast(kind * 9)) or self.data == (1 << 9) + @as(u16, @intCast(kind * 73)) or self.data == (1 << 12) + @as(u16, @intCast(kind * 585));
    }

    fn push(self: *Room, kind: usize) void {
        self.data = (self.data << 3) | @as(u16, @intCast(kind));
    }

    fn spaces(self: Room, index: usize) usize {
        const adjusted = 3 * (self.size() - 1 - index);
        return @as(usize, (self.data >> @as(u4, @intCast(adjusted))) & 0b111);
    }
};

const Hallway = struct {
    data: usize,

    fn new() Hallway {
        return .{ .data = 0x55454545455 };
    }

    fn get(self: Hallway, index: usize) usize {
        return (self.data >> @as(u6, @intCast(index * 4))) & 0xf;
    }

    fn set(self: *Hallway, index: usize, value: usize) void {
        const mask = ~(@as(usize, 0xf) << @as(u6, @intCast(index * 4)));
        const val = value << @as(u6, @intCast(index * 4));
        self.data = (self.data & mask) | val;
    }
};

const Burrow = struct {
    hallway: Hallway,
    rooms: [4]Room,

    fn new(rooms: [4][4]usize) Burrow {
        return .{ .hallway = Hallway.new(), .rooms = .{ Room.new(rooms[0]), Room.new(rooms[1]), Room.new(rooms[2]), Room.new(rooms[3]) } };
    }
};

const RangeIter = struct {
    current: isize,
    end: isize,
    step: isize,

    fn init(start: isize, end: isize, step: isize) RangeIter {
        return .{ .current = start, .end = end, .step = step };
    }

    fn next(self: *RangeIter) ?usize {
        if (self.step > 0) {
            if (self.current >= self.end) return null;
        } else {
            if (self.current <= self.end) return null;
        }
        const value = self.current;
        self.current += self.step;
        return @as(usize, @intCast(value));
    }
};

fn parse(input: []const u8, allocator: std.mem.Allocator) []const []usize {
    var lines = std.ArrayListUnmanaged([]usize){};
    defer lines.deinit(allocator);

    var it = std.mem.splitScalar(u8, input, '\n');
    while (it.next()) |raw| {
        const line = std.mem.trimRight(u8, raw, "\r");
        if (line.len == 0) continue;
        var row = std.ArrayListUnmanaged(usize){};
        var i: usize = 0;
        while (i < line.len) : (i += 1) {
            const v = line[i];
            const pod = if (v >= 'A' and v <= 'D') @as(usize, v - 'A') else 5;
            row.append(allocator, pod) catch unreachable;
        }
        lines.append(allocator, row.toOwnedSlice(allocator) catch unreachable) catch unreachable;
    }

    return lines.toOwnedSlice(allocator) catch unreachable;
}

fn bestPossible(burrow: *const Burrow) usize {
    var energy: usize = 0;
    var need_to_move = [_]usize{ 0, 0, 0, 0 };
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        const room = burrow.rooms[i];
        var blocker = false;
        var depth: usize = 0;
        while (depth < room.size()) : (depth += 1) {
            const kind = room.spaces(depth);
            if (kind != i) {
                blocker = true;
                need_to_move[kind] += 1;
                const up = 4 - depth;
                const across = 2 * absDiff(kind, i);
                const down = need_to_move[kind];
                energy += COST[kind] * (up + across + down);
            } else if (blocker) {
                need_to_move[kind] += 1;
                const up = 4 - depth;
                const across = 2;
                const down = need_to_move[kind];
                energy += COST[kind] * (up + across + down);
            }
        }
    }
    return energy;
}

fn deadlockLeft(burrow: *const Burrow) bool {
    const room = burrow.rooms[0];
    const size = room.size();
    return burrow.hallway.get(3) == A and size >= 3 and room.spaces(size - 3) != A;
}

fn deadlockRight(burrow: *const Burrow) bool {
    const room = burrow.rooms[3];
    const size = room.size();
    return burrow.hallway.get(7) == D and size >= 3 and room.spaces(size - 3) != D;
}

fn deadlockRoom(burrow: *const Burrow, kind: usize) bool {
    const left_kind = burrow.hallway.get(1 + 2 * kind);
    const right_kind = burrow.hallway.get(3 + 2 * kind);
    return left_kind != EMPTY and right_kind != EMPTY and left_kind >= kind and right_kind <= kind and !(burrow.rooms[kind].open(kind) and (kind == right_kind or kind == left_kind));
}

fn condense(burrow: *Burrow, kind: usize, iter: *RangeIter) bool {
    var changed = false;
    while (iter.next()) |hallway_index| {
        const pod = burrow.hallway.get(hallway_index);
        if (pod == EMPTY) {
            continue;
        } else if (pod == ROOM) {
            const room_index = (hallway_index - 2) / 2;
            while (burrow.rooms[room_index].peek() == kind) {
                _ = burrow.rooms[room_index].pop();
                burrow.rooms[kind].push(kind);
                changed = true;
            }
        } else if (pod == kind) {
            burrow.hallway.set(hallway_index, EMPTY);
            burrow.rooms[kind].push(kind);
            changed = true;
        } else {
            break;
        }
    }
    return changed;
}

const Node = struct { energy: usize, burrow: Burrow };

fn compare(_: void, a: Node, b: Node) std.math.Order {
    return std.math.order(a.energy, b.energy);
}

fn expand(queue: *std.PriorityQueue(Node, void, compare), seen: *std.AutoHashMap(Burrow, usize), burrow: Burrow, energy: usize, room_index: usize, iter: *RangeIter) void {
    var mut_burrow = burrow;
    const kind = mut_burrow.rooms[room_index].pop();
    while (iter.next()) |hallway_index| {
        const pod = mut_burrow.hallway.get(hallway_index);
        if (pod == ROOM) continue;
        if (pod == EMPTY) {
            var next = mut_burrow;
            next.hallway.set(hallway_index, kind);
            if (deadlockLeft(&next) or deadlockRight(&next) or deadlockRoom(&next, 0) or deadlockRoom(&next, 1) or deadlockRoom(&next, 2) or deadlockRoom(&next, 3)) continue;
            const start = 2 + 2 * room_index;
            const end = 2 + 2 * kind;
            const adjust = if (start == end) absDiff(hallway_index, start) - 1 else blk: {
                const lower = @min(start, end);
                const upper = @max(start, end);
                const left = if (hallway_index < lower) lower - hallway_index else 0;
                const right = if (hallway_index > upper) hallway_index - upper else 0;
                break :blk left + right;
            };
            const extra = COST[kind] * 2 * adjust;
            if (kind != room_index and extra == 0) continue;
            const next_energy = energy + extra;
            const min = seen.get(next) orelse std.math.maxInt(usize);
            if (next_energy < min) {
                queue.add(.{ .energy = next_energy, .burrow = next }) catch unreachable;
                seen.put(next, next_energy) catch unreachable;
            }
        } else {
            break;
        }
    }
}

fn organize(burrow: Burrow, allocator: std.mem.Allocator) usize {
    var queue = std.PriorityQueue(Node, void, compare).init(allocator, {});
    defer queue.deinit();
    var seen = std.AutoHashMap(Burrow, usize).init(allocator);
    defer seen.deinit();

    queue.add(.{ .energy = bestPossible(&burrow), .burrow = burrow }) catch unreachable;

    while (queue.removeOrNull()) |node| {
        const energy = node.energy;
        var b = node.burrow;
        const open = [_]bool{ b.rooms[0].open(0), b.rooms[1].open(1), b.rooms[2].open(2), b.rooms[3].open(3) };

        var changed = false;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            if (open[i] and b.rooms[i].size() < 4) {
                const offset = 2 + 2 * i;
                var forward = RangeIter.init(@as(isize, @intCast(offset + 1)), 11, 1);
                if (condense(&b, i, &forward)) changed = true;
                var backward = RangeIter.init(@as(isize, @intCast(offset - 1)), -1, -1);
                if (condense(&b, i, &backward)) changed = true;
            }
        }

        if (changed) {
            if (open[0] and open[1] and open[2] and open[3] and b.rooms[0].size() == 4 and b.rooms[1].size() == 4 and b.rooms[2].size() == 4 and b.rooms[3].size() == 4) return energy;
            const min = seen.get(b) orelse std.math.maxInt(usize);
            if (energy < min) {
                queue.add(.{ .energy = energy, .burrow = b }) catch unreachable;
                seen.put(b, energy) catch unreachable;
            }
        } else {
            i = 0;
            while (i < 4) : (i += 1) {
                if (!open[i]) {
                    const offset = 2 + 2 * i;
                    var forward = RangeIter.init(@as(isize, @intCast(offset + 1)), 11, 1);
                    expand(&queue, &seen, b, energy, i, &forward);
                    var backward = RangeIter.init(@as(isize, @intCast(offset - 1)), -1, -1);
                    expand(&queue, &seen, b, energy, i, &backward);
                }
            }
        }
    }
    return 0;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const lines = parse(input, allocator);
    defer {
        for (lines) |line| allocator.free(line);
        allocator.free(lines);
    }

    const burrow1 = Burrow.new(.{
        .{ A, A, lines[3][3], lines[2][3] },
        .{ B, B, lines[3][5], lines[2][5] },
        .{ C, C, lines[3][7], lines[2][7] },
        .{ D, D, lines[3][9], lines[2][9] },
    });
    const burrow2 = Burrow.new(.{
        .{ lines[3][3], D, D, lines[2][3] },
        .{ lines[3][5], B, C, lines[2][5] },
        .{ lines[3][7], A, B, lines[2][7] },
        .{ lines[3][9], C, A, lines[2][9] },
    });

    const p1 = organize(burrow1, allocator);
    const p2 = organize(burrow2, allocator);
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
