const std = @import("std");

const Result = struct { p1: i32, p2: i32 };

const Group = struct {
    units: i32,
    hp: i32,
    attack: i32,
    attack_type: u32, 
    initiative: i32,
    weak: u32, 
    immune: u32, 
    army: u8, 
    chosen: u32 = 0,
    
    fn effectivePower(self: Group) i32 {
        return self.units * self.attack;
    }
    
    fn actualDamage(self: Group, other: *const Group) i32 {
        if (self.attack_type & other.weak != 0) {
            return 2 * self.effectivePower();
        } else if (self.attack_type & other.immune == 0) {
            return self.effectivePower();
        }
        return 0;
    }
    
    fn targetSelectionOrder(self: Group) struct { i32, i32 } {
        return .{ -self.effectivePower(), -self.initiative };
    }
};

fn parseAttackType(name: []const u8, type_map: *std.StringHashMap(u32)) u32 {
    if (type_map.get(name)) |mask| {
        return mask;
    }
    const mask = @as(u32, 1) << @intCast(type_map.count());
    type_map.put(name, mask) catch unreachable;
    return mask;
}

fn parseGroups(input: []const u8, allocator: std.mem.Allocator, type_map: *std.StringHashMap(u32)) std.ArrayList(Group) {
    var groups = std.ArrayList(Group){};
    
    var lines = std.mem.splitScalar(u8, input, '\n');
    var army: u8 = 0;
    
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \r\t");
        if (trimmed.len == 0) continue;
        
        if (std.mem.indexOf(u8, trimmed, "Immune System:")) |_| {
            army = 0;
            continue;
        }
        if (std.mem.indexOf(u8, trimmed, "Infection:")) |_| {
            army = 1;
            continue;
        }
        
        
        var units: i32 = 0;
        var hp: i32 = 0;
        var attack: i32 = 0;
        var attack_type: u32 = 0;
        var initiative: i32 = 0;
        var weak: u32 = 0;
        var immune: u32 = 0;
        
        
        var parts = std.mem.splitScalar(u8, trimmed, ' ');
        var state: u8 = 0;
        
        while (parts.next()) |part| {
            if (part.len == 0) continue;
            
            if (std.fmt.parseInt(i32, part, 10)) |num| {
                if (state == 0) {
                    units = num;
                    state = 1;
                } else if (state == 1 and units > 0) {
                    hp = num;
                    state = 2;
                } else if (state == 2) {
                    attack = num;
                    state = 3;
                } else if (state == 3) {
                    initiative = num;
                }
            } else |_| {
                if (std.mem.eql(u8, part, "fire") or std.mem.eql(u8, part, "cold") or 
                    std.mem.eql(u8, part, "slashing") or std.mem.eql(u8, part, "bludgeoning") or
                    std.mem.eql(u8, part, "radiation")) {
                    if (state == 3) {
                        attack_type = parseAttackType(part, type_map);
                    }
                }
            }
        }
        
        
        if (std.mem.indexOf(u8, trimmed, "(")) |start| {
            if (std.mem.indexOf(u8, trimmed[start..], ")")) |len| {
                const modifiers = trimmed[start + 1 .. start + len];
                
                var mod_parts = std.mem.splitSequence(u8, modifiers, "; ");
                while (mod_parts.next()) |mod| {
                    if (std.mem.startsWith(u8, mod, "weak to ")) {
                        var weak_parts = std.mem.splitSequence(u8, mod[8..], ", ");
                        while (weak_parts.next()) |w| {
                            weak |= parseAttackType(w, type_map);
                        }
                    } else if (std.mem.startsWith(u8, mod, "immune to ")) {
                        var immune_parts = std.mem.splitSequence(u8, mod[10..], ", ");
                        while (immune_parts.next()) |im| {
                            immune |= parseAttackType(im, type_map);
                        }
                    }
                }
            }
        }
        
        if (units > 0) {
            groups.append(allocator, Group{
                .units = units,
                .hp = hp,
                .attack = attack,
                .attack_type = attack_type,
                .initiative = initiative,
                .weak = weak,
                .immune = immune,
                .army = army,
            }) catch unreachable;
        }
    }
    
    return groups;
}

const FightResult = enum { immune_win, infection_win, draw };

fn simulate(groups_in: []const Group, boost: i32, allocator: std.mem.Allocator) struct { FightResult, i32 } {
    var groups = std.ArrayList(Group){};
    defer groups.deinit(allocator);
    
    for (groups_in) |g| {
        var group = g;
        if (group.army == 0) group.attack += boost;
        groups.append(allocator, group) catch unreachable;
    }
    
    var turn: u32 = 1;
    while (turn < 10000) : (turn += 1) {
        
        var attacks = std.ArrayList(?struct { usize, usize }){};
        defer attacks.deinit(allocator);
        attacks.resize(allocator, groups.items.len) catch unreachable;
        @memset(attacks.items, null);
        
        
        var order = std.ArrayList(usize){};
        defer order.deinit(allocator);
        for (0..groups.items.len) |i| {
            if (groups.items[i].units > 0) {
                order.append(allocator, i) catch unreachable;
            }
        }
        
        std.mem.sort(usize, order.items, groups.items, struct {
            fn lessThan(gs: []Group, a: usize, b: usize) bool {
                const ord_a = gs[a].targetSelectionOrder();
                const ord_b = gs[b].targetSelectionOrder();
                if (ord_a[0] != ord_b[0]) return ord_a[0] < ord_b[0];
                return ord_a[1] < ord_b[1];
            }
        }.lessThan);
        
        
        for (order.items) |i| {
            const attacker = groups.items[i];
            if (attacker.units <= 0) continue;
            
            var best_damage: i32 = 0;
            var best_target: ?usize = null;
            
            for (0..groups.items.len) |j| {
                const defender = &groups.items[j];
                if (defender.units <= 0) continue;
                if (defender.army == attacker.army) continue;
                if (defender.chosen == turn) continue;
                
                const damage = attacker.actualDamage(defender);
                if (damage == 0) continue;
                
                const better = if (best_target) |bt| blk: {
                    const curr_def = &groups.items[bt];
                    break :blk damage > best_damage or
                        (damage == best_damage and defender.effectivePower() > curr_def.effectivePower()) or
                        (damage == best_damage and defender.effectivePower() == curr_def.effectivePower() and defender.initiative > curr_def.initiative);
                } else true;
                
                if (better) {
                    best_damage = damage;
                    best_target = j;
                }
            }
            
            if (best_target) |t| {
                groups.items[t].chosen = turn;
                attacks.items[i] = .{ i, t };
            }
        }
        
        
        std.mem.sort(usize, order.items, groups.items, struct {
            fn lessThan(gs: []Group, a: usize, b: usize) bool {
                return gs[a].initiative > gs[b].initiative;
            }
        }.lessThan);
        
        var total_killed: i32 = 0;
        for (order.items) |i| {
            if (groups.items[i].units <= 0) continue;
            if (attacks.items[i]) |target| {
                const attacker = groups.items[target[0]];
                const defender = &groups.items[target[1]];
                
                const damage = attacker.actualDamage(defender);
                const killed = @min(@divTrunc(damage, defender.hp), defender.units);
                defender.units -= killed;
                total_killed += killed;
            }
        }
        
        if (total_killed == 0) {
            return .{ .draw, 0 };
        }
        
        
        var immune_units: i32 = 0;
        var infection_units: i32 = 0;
        for (groups.items) |g| {
            if (g.units > 0) {
                if (g.army == 0) immune_units += g.units;
                if (g.army == 1) infection_units += g.units;
            }
        }
        
        if (immune_units == 0) return .{ .infection_win, infection_units };
        if (infection_units == 0) return .{ .immune_win, immune_units };
    }
    
    return .{ .draw, 0 };
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var type_map = std.StringHashMap(u32).init(allocator);
    defer type_map.deinit();
    
    var groups = parseGroups(input, allocator, &type_map);
    defer groups.deinit(allocator);
    
    
    const result1 = simulate(groups.items, 0, allocator);
    const part1 = result1[1];
    
    
    var low: i32 = 1;
    var high: i32 = 10000;
    var part2: i32 = 0;
    
    while (low <= high) {
        const mid = @divTrunc(low + high, 2);
        const result = simulate(groups.items, mid, allocator);
        
        if (result[0] == .immune_win) {
            part2 = result[1];
            high = mid - 1;
        } else {
            low = mid + 1;
        }
    }
    
    return Result{ .p1 = part1, .p2 = part2 };
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
