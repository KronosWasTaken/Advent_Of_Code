const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const cwd = std.fs.cwd();
    const file_content = try cwd.readFileAlloc(allocator, "input.txt", 1024);
    defer allocator.free(file_content);
    var timer = try std.time.Timer.start();
    const result = try solve(allocator, file_content);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn solve(allocator: std.mem.Allocator, input: []const u8) !Result {
    const initial = try parseInput(allocator, input);
    const p1 = try bfs(allocator, initial);

var p2_state = initial;

    var used_mask: u16 = 0;
    for (initial.floors) |f| used_mask |= f;
    var next_bit: u4 = 0;
    while (next_bit < 16) : (next_bit += 2) {
        if (used_mask & (@as(u16, 0b11) << next_bit) == 0) break;
    }

    if (next_bit <= 12) {
        p2_state.floors[0] |= (@as(u16, 0b11) << next_bit);
        p2_state.floors[0] |= (@as(u16, 0b11) << (next_bit + 2));
    }
    const p2 = try bfs(allocator, p2_state);
    return .{ .p1 = p1, .p2 = p2 };
}
const State = struct {
    elevator: u2,
    floors: [4]u16,
    fn isValid(self: State) bool {
        for (self.floors) |floor| {
            if (floor == 0) continue;

            const gens = (floor & 0xAAAA) >> 1;
            const chips = floor & 0x5555;

            if (gens != 0) {

if ((chips & ~gens) != 0) return false;
            }
        }
        return true;
    }
    fn isDone(self: State) bool {
        return self.floors[0] == 0 and self.floors[1] == 0 and self.floors[2] == 0;
    }

fn normalize(self: State) State {
        var pair_locs: [8]u8 = undefined;
        var count: usize = 0;
        for (0..8) |i| {
            const shift: u4 = @intCast(i * 2);
            const chip_mask = @as(u16, 1) << shift;
            const gen_mask = @as(u16, 1) << (shift + 1);
            var c_floor: u2 = 0;
            var g_floor: u2 = 0;
            var found = false;
            for (self.floors, 0..) |f, idx| {
                if (f & chip_mask != 0) { c_floor = @intCast(idx); found = true; }
                if (f & gen_mask != 0) { g_floor = @intCast(idx); found = true; }
            }
            if (found) {
                pair_locs[count] = (@as(u8, g_floor) << 2) | c_floor;
                count += 1;
            }
        }
        std.mem.sort(u8, pair_locs[0..count], {}, std.sort.asc(u8));
        var norm = State{ .elevator = self.elevator, .floors = .{0, 0, 0, 0} };
        for (pair_locs[0..count], 0..) |loc, i| {
            const g_floor = loc >> 2;
            const c_floor = loc & 3;
            const shift: u4 = @intCast(i * 2);
            norm.floors[g_floor] |= @as(u16, 1) << (shift + 1);
            norm.floors[c_floor] |= @as(u16, 1) << shift;
        }
        return norm;
    }
};
const Item = struct { s: State, dist: u32 };
fn bfs(allocator: std.mem.Allocator, initial: State) !u32 {
    var queue = std.ArrayListUnmanaged(Item){};
    defer queue.deinit(allocator);
    var seen = std.AutoHashMap(State, void).init(allocator);
    defer seen.deinit();
    try queue.append(allocator, .{ .s = initial, .dist = 0 });
    try seen.put(initial.normalize(), {});
    var head: usize = 0;
    while (head < queue.items.len) {
        const current_item = queue.items[head];
        head += 1;
        const state = current_item.s;
        const dist = current_item.dist;
        if (state.isDone()) return dist;
        const e = state.elevator;

        var next_floors_buf: [2]u2 = undefined;
        var next_count: usize = 0;
        if (e < 3) { next_floors_buf[next_count] = e + 1; next_count += 1; }
        if (e > 0) { next_floors_buf[next_count] = e - 1; next_count += 1; }
        const next_floors = next_floors_buf[0..next_count];
        const current_items = state.floors[e];
        if (current_items == 0) continue;

        var items: [16]u4 = undefined;
        var item_count: usize = 0;
        for (0..16) |i| {
            if (current_items & (@as(u16, 1) << @intCast(i)) != 0) {
                items[item_count] = @intCast(i);
                item_count += 1;
            }
        }

for (0..item_count) |i| {
            for (i + 1..item_count) |j| {
                const mask = (@as(u16, 1) << items[i]) | (@as(u16, 1) << items[j]);
                for (next_floors) |nf| {
                    if (isValidMove(state, mask, e, nf)) |next_state| {
                        const norm = next_state.normalize();
                        if (!seen.contains(norm)) {
                            try seen.put(norm, {});
                            try queue.append(allocator, .{ .s = next_state, .dist = dist + 1 });
                        }
                    }
                }
            }
        }

        for (0..item_count) |i| {
            const mask = (@as(u16, 1) << items[i]);
             for (next_floors) |nf| {

if (isValidMove(state, mask, e, nf)) |next_state| {
                     const norm = next_state.normalize();
                    if (!seen.contains(norm)) {
                        try seen.put(norm, {});
                        try queue.append(allocator, .{ .s = next_state, .dist = dist + 1 });
                    }
                }
            }
        }
    }
    return 0;
}
fn isValidMove(current: State, move_mask: u16, from: u2, to: u2) ?State {
    var next = current;
    next.elevator = to;
    next.floors[from] &= ~move_mask;
    next.floors[to] |= move_mask;

    if (!isValidFloor(next.floors[from])) return null;
    if (!isValidFloor(next.floors[to])) return null;
    return next;
}
fn isValidFloor(floor: u16) bool {
    if (floor == 0) return true;
    const gens = (floor & 0xAAAA) >> 1;
    const chips = floor & 0x5555;
    if (gens != 0) {
        if ((chips & ~gens) != 0) return false;
    }
    return true;
}
fn parseInput(allocator: std.mem.Allocator, input: []const u8) !State {
    var state = State{ .elevator = 0, .floors = .{0, 0, 0, 0} };
    var map = std.StringHashMap(u4).init(allocator);
    defer map.deinit();
    var next_id: u4 = 0;
    var lines = std.mem.tokenizeScalar(u8, input, '\n');
    var floor: usize = 0;
    while (lines.next()) |line| : (floor += 1) {
        var it = std.mem.tokenizeAny(u8, line, " .,-");
        while (it.next()) |word| {

if (std.mem.eql(u8, word, "generator")) {

}
        }
    }

lines = std.mem.tokenizeScalar(u8, input, '\n');
    floor = 0;
    while (lines.next()) |line| : (floor += 1) {

        var i: usize = 0;
        while (std.mem.indexOfPos(u8, line, i, " generator")) |pos| {

            const element_end = pos;
            var element_start = element_end;
            while (element_start > 0 and line[element_start-1] != ' ') : (element_start -= 1) {}
            const element = line[element_start..element_end];
            const id = if (map.get(element)) |id| id else blk: {
                try map.put(element, next_id);
                next_id += 1;
                break :blk next_id - 1;
            };
            state.floors[floor] |= @as(u16, 1) << (id * 2 + 1);
            i = pos + 1;
        }

        i = 0;
        while (std.mem.indexOfPos(u8, line, i, "-compatible microchip")) |pos| {

            const element_end = pos;
            var element_start = element_end;
            while (element_start > 0 and line[element_start-1] != ' ') : (element_start -= 1) {}
            const element = line[element_start..element_end];
            const id = if (map.get(element)) |id| id else blk: {
                try map.put(element, next_id);
                next_id += 1;
                break :blk next_id - 1;
            };
            state.floors[floor] |= @as(u16, 1) << (id * 2);
            i = pos + 1;
        }
    }
    return state;
}
