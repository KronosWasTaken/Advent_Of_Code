const std = @import("std");
const State = packed struct {
    boss_hp: i16,
    player_hp: i16,
    player_mana: i16,
    shield_effect: u8,
    poison_effect: u8,
    recharge_effect: u8,
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
    inline fn bossTurn(self: *State, attack: i16) bool {
        var damage = attack;
        if (self.shield_effect > 0) {
            damage = @max(damage - 7, 1);
        }
        self.player_hp -= damage;
        return self.player_hp > 0 and self.player_mana >= 53;
    }
};
const QueueItem = struct {
    mana: i16,
    state: State,
};
fn lessThan(_: void, a: QueueItem, b: QueueItem) std.math.Order {
    return std.math.order(a.mana, b.mana);
}
fn play(boss_hp: i16, boss_dmg: i16, hard_mode: bool) !i16 {
    @setRuntimeSafety(false);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var pq = std.PriorityQueue(QueueItem, void, lessThan).init(allocator, {});
    var cache = std.AutoHashMap(State, void).init(allocator);
    try cache.ensureTotalCapacity(5000);
    const start = State{
        .boss_hp = boss_hp,
        .player_hp = 50,
        .player_mana = 500,
        .shield_effect = 0,
        .poison_effect = 0,
        .recharge_effect = 0,
    };
    try pq.add(.{ .mana = 0, .state = start });
    try cache.put(start, {});
    while (pq.removeOrNull()) |item| {
        var state = item.state;
        const spent = item.mana;
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
            if (next.bossTurn(boss_dmg)) {
                const gop = cache.getOrPutAssumeCapacity(next);
                if (!gop.found_existing) {
                    gop.value_ptr.* = {};
                    try pq.add(.{ .mana = spent + 53, .state = next });
                }
            }
        }
        if (state.player_mana >= 73) {
            var next = state;
            next.boss_hp -= 2;
            next.player_hp += 2;
            next.player_mana -= 73;
            if (next.applyEffects()) return spent + 73;
            if (next.bossTurn(boss_dmg)) {
                const gop = cache.getOrPutAssumeCapacity(next);
                if (!gop.found_existing) {
                    gop.value_ptr.* = {};
                    try pq.add(.{ .mana = spent + 73, .state = next });
                }
            }
        }
        if (state.player_mana >= 113 and state.shield_effect == 0) {
            var next = state;
            next.player_mana -= 113;
            next.shield_effect = 6;
            if (next.applyEffects()) return spent + 113;
            if (next.bossTurn(boss_dmg)) {
                const gop = cache.getOrPutAssumeCapacity(next);
                if (!gop.found_existing) {
                    gop.value_ptr.* = {};
                    try pq.add(.{ .mana = spent + 113, .state = next });
                }
            }
        }
        if (state.player_mana >= 173 and state.poison_effect == 0) {
            var next = state;
            next.player_mana -= 173;
            next.poison_effect = 6;
            if (next.applyEffects()) return spent + 173;
            if (next.bossTurn(boss_dmg)) {
                const gop = cache.getOrPutAssumeCapacity(next);
                if (!gop.found_existing) {
                    gop.value_ptr.* = {};
                    try pq.add(.{ .mana = spent + 173, .state = next });
                }
            }
        }
        if (state.player_mana >= 229 and state.recharge_effect == 0) {
            var next = state;
            next.player_mana -= 229;
            next.recharge_effect = 5;
            if (next.applyEffects()) return spent + 229;
            if (next.bossTurn(boss_dmg)) {
                const gop = cache.getOrPutAssumeCapacity(next);
                if (!gop.found_existing) {
                    gop.value_ptr.* = {};
                    try pq.add(.{ .mana = spent + 229, .state = next });
                }
            }
        }
    }
    return 0;
}
fn solve(input: []const u8) !struct { p1: i16, p2: i16 } {
    var nums: [2]i16 = .{0} ** 2;
    var idx: usize = 0;
    var in_number = false;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            nums[idx] = nums[idx] * 10 + (c - '0');
            in_number = true;
        } else if (in_number and idx < 1) {
            idx += 1;
            in_number = false;
        }
    }
    const p1 = try play(nums[0], nums[1], false);
    const p2 = try play(nums[0], nums[1], true);
    return .{ .p1 = p1, .p2 = p2 };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {d} | Part 2: {d}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
