const std = @import("std");

const State = packed struct(u64) {
    boss_hp: i8,
    player_hp: i8,
    player_mana: i16,
    shield_effect: u4,
    poison_effect: u4,
    recharge_effect: u4,
    _pad: u20 = 0,

    inline fn applyEffects(self: *State) bool {
        if (self.shield_effect > 0) self.shield_effect -= 1;
        if (self.poison_effect > 0) {
            self.poison_effect -= 1;
            self.boss_hp -= 3;
        }
        if (self.recharge_effect > 0) {
            self.recharge_effect -= 1;
            self.player_mana += 101;
        }
        return self.boss_hp <= 0;
    }

    inline fn bossTurn(self: *State, attack: i8) bool {
        var damage = attack;
        if (self.shield_effect > 0) {
            damage = @max(damage - 7, 1);
        }
        self.player_hp -= damage;
        return self.player_hp > 0 and self.player_mana >= 53;
    }
};

const HeapItem = struct {
    cost: i16,
    state: State,
};

const MinHeap = struct {
    items: [4096]HeapItem = undefined,
    len: usize = 0,

    inline fn push(self: *MinHeap, item: HeapItem) void {
        var i = self.len;
        self.len += 1;
        while (i > 0) {
            const parent = (i - 1) >> 1;
            if (self.items[parent].cost <= item.cost) break;
            self.items[i] = self.items[parent];
            i = parent;
        }
        self.items[i] = item;
    }

    inline fn pop(self: *MinHeap) ?HeapItem {
        if (self.len == 0) return null;
        const res = self.items[0];
        self.len -= 1;
        if (self.len > 0) {
            const last = self.items[self.len];
            var i: usize = 0;
            const half = self.len >> 1;
            while (i < half) {
                var child = (i << 1) + 1;
                const right = child + 1;
                if (right < self.len and self.items[right].cost < self.items[child].cost) {
                    child = right;
                }
                if (last.cost <= self.items[child].cost) break;
                self.items[i] = self.items[child];
                i = child;
            }
            self.items[i] = last;
        }
        return res;
    }
};

const StateSet = struct {
    keys: [16384]u64 = [_]u64{0} ** 16384,

    inline fn insert(self: *StateSet, state: State) bool {
        const raw: u64 = @as(u64, @bitCast(state)) | (@as(u64, 1) << 63);
        const h = raw *% 0x517cc1b727220a95;
        var idx = @as(usize, @truncate(h)) & 16383;
        while (true) {
            const k = self.keys[idx];
            if (k == raw) return false;
            if (k == 0) {
                self.keys[idx] = raw;
                return true;
            }
            idx = (idx + 1) & 16383;
        }
    }
};

fn play(boss_hp: i8, boss_dmg: i8, hard_mode: bool) i16 {
    @setRuntimeSafety(false);
    var heap = MinHeap{};
    var cache = StateSet{};

    const start = State{
        .boss_hp = boss_hp,
        .player_hp = 50,
        .player_mana = 500,
        .shield_effect = 0,
        .poison_effect = 0,
        .recharge_effect = 0,
    };
    heap.push(.{ .cost = 0, .state = start });
    _ = cache.insert(start);

    while (heap.pop()) |item| {
        var state = item.state;
        const spent = item.cost;
        if (state.applyEffects()) return spent;
        if (hard_mode) {
            if (state.player_hp > 1) {
                state.player_hp -= 1;
            } else {
                continue;
            }
        }

        if (state.player_mana >= 53) {
            var next = state;
            next.boss_hp -= 4;
            next.player_mana -= 53;
            if (next.applyEffects()) return spent + 53;
            if (next.bossTurn(boss_dmg) and cache.insert(next)) {
                heap.push(.{ .cost = spent + 53, .state = next });
            }
        }
        if (state.player_mana >= 73) {
            var next = state;
            next.boss_hp -= 2;
            next.player_hp += 2;
            next.player_mana -= 73;
            if (next.applyEffects()) return spent + 73;
            if (next.bossTurn(boss_dmg) and cache.insert(next)) {
                heap.push(.{ .cost = spent + 73, .state = next });
            }
        }
        if (state.player_mana >= 113 and state.shield_effect == 0) {
            var next = state;
            next.player_mana -= 113;
            next.shield_effect = 6;
            if (next.applyEffects()) return spent + 113;
            if (next.bossTurn(boss_dmg) and cache.insert(next)) {
                heap.push(.{ .cost = spent + 113, .state = next });
            }
        }
        if (state.player_mana >= 173 and state.poison_effect == 0) {
            var next = state;
            next.player_mana -= 173;
            next.poison_effect = 6;
            if (next.applyEffects()) return spent + 173;
            if (next.bossTurn(boss_dmg) and cache.insert(next)) {
                heap.push(.{ .cost = spent + 173, .state = next });
            }
        }
        if (state.player_mana >= 229 and state.recharge_effect == 0) {
            var next = state;
            next.player_mana -= 229;
            next.recharge_effect = 5;
            if (next.applyEffects()) return spent + 229;
            if (next.bossTurn(boss_dmg) and cache.insert(next)) {
                heap.push(.{ .cost = spent + 229, .state = next });
            }
        }
    }
    return 0;
}

fn solve(input: []const u8) struct { p1: i16, p2: i16 } {
    var nums: [2]i8 = .{0} ** 2;
    var idx: usize = 0;
    var in_number = false;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            nums[idx] = nums[idx] * 10 + @as(i8, @intCast(c - '0'));
            in_number = true;
        } else if (in_number and idx < 1) {
            idx += 1;
            in_number = false;
        }
    }

    const p1 = play(nums[0], nums[1], false);
    const p2 = play(nums[0], nums[1], true);

    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {d} | Part 2: {d}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
