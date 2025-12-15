const std = @import("std");
const Item = struct {
    cost: u32,
    damage: u32,
    armor: u32,
    fn add(self: Item, other: Item) Item {
        return .{
            .cost = self.cost + other.cost,
            .damage = self.damage + other.damage,
            .armor = self.armor + other.armor,
        };
    }
};
const weapons = [_]Item{
    .{ .cost = 8, .damage = 4, .armor = 0 },
    .{ .cost = 10, .damage = 5, .armor = 0 },
    .{ .cost = 25, .damage = 6, .armor = 0 },
    .{ .cost = 40, .damage = 7, .armor = 0 },
    .{ .cost = 74, .damage = 8, .armor = 0 },
};
const armors = [_]Item{
    .{ .cost = 0, .damage = 0, .armor = 0 }, // No armor
    .{ .cost = 13, .damage = 0, .armor = 1 },
    .{ .cost = 31, .damage = 0, .armor = 2 },
    .{ .cost = 53, .damage = 0, .armor = 3 },
    .{ .cost = 75, .damage = 0, .armor = 4 },
    .{ .cost = 102, .damage = 0, .armor = 5 },
};
const rings = [_]Item{
    .{ .cost = 25, .damage = 1, .armor = 0 },
    .{ .cost = 50, .damage = 2, .armor = 0 },
    .{ .cost = 100, .damage = 3, .armor = 0 },
    .{ .cost = 20, .damage = 0, .armor = 1 },
    .{ .cost = 40, .damage = 0, .armor = 2 },
    .{ .cost = 80, .damage = 0, .armor = 3 },
};
fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var nums: [3]u32 = .{0} ** 3;
    var idx: usize = 0;
    var in_number = false;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            nums[idx] = nums[idx] * 10 + (c - '0');
            in_number = true;
        } else if (in_number and idx < 2) {
            idx += 1;
            in_number = false;
        }
    }
    const boss_hp = nums[0];
    const boss_dmg = nums[1];
    const boss_armor = nums[2];
    var ring_combos: [22]Item = undefined;
    var combo_idx: usize = 0;
    ring_combos[combo_idx] = .{ .cost = 0, .damage = 0, .armor = 0 };
    combo_idx += 1;
    for (rings) |ring| {
        ring_combos[combo_idx] = ring;
        combo_idx += 1;
    }
    for (0..rings.len) |i| {
        for (i + 1..rings.len) |j| {
            ring_combos[combo_idx] = rings[i].add(rings[j]);
            combo_idx += 1;
        }
    }
    var min_cost: u32 = std.math.maxInt(u32);
    var max_cost: u32 = 0;
    for (weapons) |weapon| {
        for (armors) |armor| {
            for (ring_combos) |ring_combo| {
                const loadout = weapon.add(armor).add(ring_combo);
                const hero_damage = if (loadout.damage > boss_armor) loadout.damage - boss_armor else 1;
                const boss_damage = if (boss_dmg > loadout.armor) boss_dmg - loadout.armor else 1;
                const hero_turns = (boss_hp + hero_damage - 1) / hero_damage;
                const boss_turns = (100 + boss_damage - 1) / boss_damage;
                const win = hero_turns <= boss_turns;
                if (win) {
                    min_cost = @min(min_cost, loadout.cost);
                } else {
                    max_cost = @max(max_cost, loadout.cost);
                }
            }
        }
    }
    return .{ .p1 = min_cost, .p2 = max_cost };
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
