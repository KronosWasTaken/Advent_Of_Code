const std = @import("std");

const Mineral = struct {
    ore: u32,
    clay: u32,
    obsidian: u32,
    geode: u32,

    fn from(ore: u32, clay: u32, obsidian: u32, geode: u32) Mineral {
        return .{ .ore = ore, .clay = clay, .obsidian = obsidian, .geode = geode };
    }

    fn lessEqual(self: Mineral, rhs: Mineral) bool {
        return self.ore <= rhs.ore and self.clay <= rhs.clay and self.obsidian <= rhs.obsidian;
    }

    fn add(self: Mineral, rhs: Mineral) Mineral {
        return .{
            .ore = self.ore + rhs.ore,
            .clay = self.clay + rhs.clay,
            .obsidian = self.obsidian + rhs.obsidian,
            .geode = self.geode + rhs.geode,
        };
    }

    fn sub(self: Mineral, rhs: Mineral) Mineral {
        return .{
            .ore = self.ore - rhs.ore,
            .clay = self.clay - rhs.clay,
            .obsidian = self.obsidian - rhs.obsidian,
            .geode = self.geode - rhs.geode,
        };
    }
};

const ZERO = Mineral.from(0, 0, 0, 0);
const ORE_BOT = Mineral.from(1, 0, 0, 0);
const CLAY_BOT = Mineral.from(0, 1, 0, 0);
const OBSIDIAN_BOT = Mineral.from(0, 0, 1, 0);
const GEODE_BOT = Mineral.from(0, 0, 0, 1);

const Blueprint = struct {
    id: u32,
    max_ore: u32,
    max_clay: u32,
    max_obsidian: u32,
    ore_cost: Mineral,
    clay_cost: Mineral,
    obsidian_cost: Mineral,
    geode_cost: Mineral,

    fn from(chunk: [7]u32) Blueprint {
        const id = chunk[0];
        const ore1 = chunk[1];
        const ore2 = chunk[2];
        const ore3 = chunk[3];
        const clay = chunk[4];
        const ore4 = chunk[5];
        const obsidian = chunk[6];
        return .{
            .id = id,
            .max_ore = @max(@max(ore1, ore2), @max(ore3, ore4)),
            .max_clay = clay,
            .max_obsidian = obsidian,
            .ore_cost = Mineral.from(ore1, 0, 0, 0),
            .clay_cost = Mineral.from(ore2, 0, 0, 0),
            .obsidian_cost = Mineral.from(ore3, clay, 0, 0),
            .geode_cost = Mineral.from(ore4, 0, obsidian, 0),
        };
    }
};

const Result = struct {
    p1: u32,
    p2: u32,
};

fn parseNumbers(input: []const u8, allocator: std.mem.Allocator) ![]u32 {
    var values = std.ArrayListUnmanaged(u32){};
    var num: u32 = 0;
    var in_num = false;
    for (input) |b| {
        if (b >= '0' and b <= '9') {
            num = num * 10 + (b - '0');
            in_num = true;
        } else if (in_num) {
            values.append(allocator, num) catch unreachable;
            num = 0;
            in_num = false;
        }
    }
    if (in_num) values.append(allocator, num) catch unreachable;
    return values.toOwnedSlice(allocator);
}

fn parse(input: []const u8, allocator: std.mem.Allocator) ![]Blueprint {
    const values = try parseNumbers(input, allocator);
    defer allocator.free(values);

    const count = values.len / 7;
    var blueprints = try allocator.alloc(Blueprint, count);
    var idx: usize = 0;
    while (idx < count) : (idx += 1) {
        var chunk: [7]u32 = undefined;
        var j: usize = 0;
        while (j < 7) : (j += 1) {
            chunk[j] = values[idx * 7 + j];
        }
        blueprints[idx] = Blueprint.from(chunk);
    }
    return blueprints;
}

fn heuristic(blueprint: *const Blueprint, result: u32, time: u32, bots: Mineral, resources: Mineral) bool {
    var local_bots = bots;
    var local_resources = resources;
    var t: u32 = 0;
    while (t < time) : (t += 1) {
        local_resources.ore = blueprint.max_ore;
        if (blueprint.geode_cost.lessEqual(local_resources)) {
            local_resources = local_resources.add(local_bots).sub(blueprint.geode_cost);
            local_bots = local_bots.add(GEODE_BOT);
        } else if (blueprint.obsidian_cost.lessEqual(local_resources)) {
            local_resources = local_resources.add(local_bots).sub(blueprint.obsidian_cost);
            local_bots = local_bots.add(OBSIDIAN_BOT);
        } else {
            local_resources = local_resources.add(local_bots);
        }
        local_bots = local_bots.add(CLAY_BOT);
    }
    return local_resources.geode > result;
}

fn next(blueprint: *const Blueprint, result: *u32, time: u32, bots: Mineral, resources: Mineral, new_bot: Mineral, cost: Mineral) void {
    var jump: u32 = 1;
    var local_resources = resources;
    while (jump < time) : (jump += 1) {
        if (cost.lessEqual(local_resources)) {
            dfs(blueprint, result, time - jump, bots.add(new_bot), local_resources.add(bots).sub(cost));
            break;
        }
        local_resources = local_resources.add(bots);
    }
}

fn dfs(blueprint: *const Blueprint, result: *u32, time: u32, bots: Mineral, resources: Mineral) void {
    const total = resources.geode + bots.geode * time;
    if (total > result.*) result.* = total;

    if (!heuristic(blueprint, result.*, time, bots, resources)) return;

    if (bots.obsidian > 0 and time > 1) {
        next(blueprint, result, time, bots, resources, GEODE_BOT, blueprint.geode_cost);
    }
    if (bots.obsidian < blueprint.max_obsidian and bots.clay > 0 and time > 3) {
        next(blueprint, result, time, bots, resources, OBSIDIAN_BOT, blueprint.obsidian_cost);
    }
    if (bots.ore < blueprint.max_ore and time > 3) {
        next(blueprint, result, time, bots, resources, ORE_BOT, blueprint.ore_cost);
    }
    if (bots.clay < blueprint.max_clay and time > 5) {
        next(blueprint, result, time, bots, resources, CLAY_BOT, blueprint.clay_cost);
    }
}

fn maximize(blueprint: *const Blueprint, time: u32) u32 {
    var result: u32 = 0;
    dfs(blueprint, &result, time, ORE_BOT, ZERO);
    return result;
}

fn solve(input: []const u8) Result {
    const allocator = std.heap.page_allocator;
    const blueprints = parse(input, allocator) catch unreachable;
    defer allocator.free(blueprints);

    var p1: u32 = 0;
    for (blueprints) |*bp| {
        p1 += bp.id * maximize(bp, 24);
    }

    var p2: u32 = 1;
    var i: usize = 0;
    while (i < blueprints.len and i < 3) : (i += 1) {
        p2 *= maximize(&blueprints[i], 32);
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
