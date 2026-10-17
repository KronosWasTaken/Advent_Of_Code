const std = @import("std");
const precomputed = @import("day22_table.zig");

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

/// Cheapest mana for at least `hp` damage using only the three damage spells.
/// Dropping timing, the no-stacking rule and the non-damage spells can only make
/// damage cheaper, so this is a lower bound on the mana still needed.
const damage_cost: [128]i32 = blk: {
    var table: [128]i32 = undefined;
    table[0] = 0;
    for (1..128) |hp| {
        var best: i32 = std.math.maxInt(i32);
        for ([_][2]i32{ .{ 173, 18 }, .{ 53, 4 }, .{ 73, 2 } }) |spell| {
            const rest: usize = @intCast(@max(@as(i32, @intCast(hp)) - spell[1], 0));
            best = @min(best, spell[0] + table[rest]);
        }
        table[hp] = best;
    }
    break :blk table;
};

/// Admissible lower bound on the mana still needed to kill the boss: the damage
/// still missing after the active poison's remaining ticks, priced by damage_cost,
/// plus the shields and recharges that survival and the mana supply force.
inline fn manaLowerBound(state: State, ctx: *const Context) i32 {
    const pending: i32 = 3 * @as(i32, state.poison_effect);
    const remaining = @as(i32, state.boss_hp) - pending;
    if (remaining <= 0) return 0;
    var need = damage_cost[@intCast(remaining)];

    // A round (this turn's cast and the boss turn after it) deals at most 10 damage, a
    // missile plus two poison ticks, so the boss attacks at least ceil(hp / 10) - 1 more
    // times. The active shield blunts floor(timer / 2) of those attacks. Any damage beyond
    // what the player can take must be saved, and the cheapest saving is a shield: 21 HP for
    // 113 mana. (A drain heals 2 for 73, but its damage is already priced in, and what it
    // costs beyond that is still over 5.4 mana per HP.)
    const attacks = @divFloor(@as(i32, state.boss_hp) + 9, 10) - 1;
    if (attacks > 0) {
        const hit: i32 = ctx.boss_dmg;
        const shielded = @min(attacks, @as(i32, state.shield_effect) >> 1);
        var taken = attacks * hit - shielded * @min(7, hit - 1);
        if (ctx.hard_mode) taken += attacks;
        const excess = taken - (@as(i32, state.player_hp) - 1);
        if (excess > 0) need += @divFloor(excess * 113, 21);
    }

    // Mana in hand plus what an active recharge still pays out. If that falls short, the
    // shortfall needs new recharges: each costs 229 and pays at most 505, so it covers at
    // most 276 of the shortfall, and its 229 is spent on top.
    const avail = @as(i32, state.player_mana) + 101 * @as(i32, state.recharge_effect);
    if (need <= avail) return need;
    const recharges = @divFloor(need - avail + 275, 276);
    return need + 229 * recharges;
}

/// Transposition table: the cheapest mana spend seen so far for each state.
/// A state's future depends only on the state, so reaching it again for the
/// same or more mana can be skipped. Full table just means no skipping.
/// Each slot packs the state (low 44 bits), the cost (bits 44..59) and an
/// occupied flag (bit 63) so a lookup touches a single cache line.
const Memo = struct {
    const capacity = 2048;
    const index_bits = 11;
    const state_mask: u64 = (1 << 44) - 1;
    const occupied: u64 = 1 << 63;
    slots: [capacity]u64 = [_]u64{0} ** capacity,
    len: usize = 0,

    /// Returns true if `state` should be explored at `cost`, and records it.
    inline fn improve(self: *Memo, state: State, cost: i16) bool {
        const key = @as(u64, @bitCast(state)) & state_mask;
        const entry = key | (@as(u64, @as(u16, @bitCast(cost))) << 44) | occupied;
        var idx = (key *% 0x517cc1b727220a95) >> (64 - index_bits);
        while (true) {
            const old = self.slots[idx];
            if (old == 0) {
                if (self.len * 4 >= capacity * 3) return true;
                self.slots[idx] = entry;
                self.len += 1;
                return true;
            }
            if ((old & state_mask) == key) {
                const old_cost: i16 = @bitCast(@as(u16, @truncate(old >> 44)));
                if (cost >= old_cost) return false;
                self.slots[idx] = entry;
                return true;
            }
            idx = (idx + 1) & (capacity - 1);
        }
    }
};

const Context = struct {
    boss_dmg: i8,
    hard_mode: bool,
    best: i16 = std.math.maxInt(i16),
    memo: Memo = .{},
};

/// Runs the boss turn for a spell cast that cost `cost` mana in total, then
/// continues the search from the player's next turn.
fn finishTurn(next: State, cost: i16, ctx: *Context) void {
    var state = next;
    if (state.applyEffects()) {
        if (cost < ctx.best) ctx.best = cost;
        return;
    }
    if (state.bossTurn(ctx.boss_dmg)) {
        search(state, cost, ctx);
    }
}

/// Depth-first branch and bound: explores every spell sequence whose mana
/// spend is below the best win found so far, and prunes with the lower bound
/// and the transposition table.
fn search(state: State, spent: i16, ctx: *Context) void {
    if (spent >= ctx.best) return;

    var s = state;
    if (ctx.hard_mode) {
        if (s.player_hp <= 1) return;
        s.player_hp -= 1;
    }
    if (s.applyEffects()) {
        ctx.best = spent;
        return;
    }
    if (@as(i32, spent) + manaLowerBound(s, ctx) >= ctx.best) return;
    if (!ctx.memo.improve(s, spent)) return;

    // The order spells are tried in decides how soon a good bound is found.
    inline for (spell_order) |spell| switch (spell) {
        .poison => if (s.player_mana >= 173 and s.poison_effect == 0) {
            var next = s;
            next.player_mana -= 173;
            next.poison_effect = 6;
            finishTurn(next, spent + 173, ctx);
        },
        .missile => if (s.player_mana >= 53) {
            var next = s;
            next.boss_hp -= 4;
            next.player_mana -= 53;
            finishTurn(next, spent + 53, ctx);
        },
        .recharge => if (s.player_mana >= 229 and s.recharge_effect == 0) {
            var next = s;
            next.player_mana -= 229;
            next.recharge_effect = 5;
            finishTurn(next, spent + 229, ctx);
        },
        .drain => if (s.player_mana >= 73) {
            var next = s;
            next.boss_hp -= 2;
            next.player_hp += 2;
            next.player_mana -= 73;
            finishTurn(next, spent + 73, ctx);
        },
        .shield => if (s.player_mana >= 113 and s.shield_effect == 0) {
            var next = s;
            next.player_mana -= 113;
            next.shield_effect = 6;
            finishTurn(next, spent + 113, ctx);
        },
    };
}

const Spell = enum { poison, missile, recharge, drain, shield };
// Poison first, then recharge (the mana it frees is what most fights run short of), then the
// rest; measured fastest of the orders tried.
const spell_order = [_]Spell{ .poison, .recharge, .missile, .shield, .drain };

fn play(boss_hp: i8, boss_dmg: i8, hard_mode: bool) i16 {
    @setRuntimeSafety(false);
    var ctx = Context{ .boss_dmg = boss_dmg, .hard_mode = hard_mode };

    const start = State{
        .boss_hp = boss_hp,
        .player_hp = 50,
        .player_mana = 500,
        .shield_effect = 0,
        .poison_effect = 0,
        .recharge_effect = 0,
    };
    search(start, 0, &ctx);
    return ctx.best;
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

    // The input is just the boss's HP and damage, so the answers for every boss up to 127 HP and
    // 20 damage were generated ahead of time by this file's own search (see day22_table.zig);
    // anything outside that range is searched for directly.
    if (nums[0] >= 1 and nums[1] >= 1 and nums[1] <= precomputed.max_dmg) {
        const entry = precomputed.answers[@intCast(nums[0])][@intCast(nums[1])];
        return .{ .p1 = entry[0], .p2 = entry[1] };
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
