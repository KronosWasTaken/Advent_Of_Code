const std = @import("std");

const Result = struct {
    p1: usize,
    p2: []const u8,
};

const Ingredient = struct {
    name: []const u8,
    food_mask: u64,
    count: usize,
    candidates: u64,
};

fn solve(allocator: std.mem.Allocator, input: []const u8) !Result {
    var ingredient_map = std.StringHashMap(usize).init(allocator);
    var allergen_map = std.StringHashMap(usize).init(allocator);
    var ingredient_list = std.ArrayListUnmanaged(Ingredient){};
    var allergen_names = std.ArrayListUnmanaged([]const u8){};
    var allergens_per_food = std.ArrayListUnmanaged(u64){};

    var lines = std.mem.splitScalar(u8, input, '\n');
    var food_index: usize = 0;
    while (lines.next()) |line_raw| : (food_index += 1) {
        var line = line_raw;
        if (line.len == 0) continue;
        if (line[line.len - 1] == '\r') line = line[0 .. line.len - 1];

        var split = std.mem.splitSequence(u8, line, " (contains ");
        const ingredient_str = split.next().?;
        const allergen_str = split.next().?;

        var allergens_mask: u64 = 0;
        var allergen_iter = std.mem.splitSequence(u8, allergen_str[0 .. allergen_str.len - 1], ", ");
        while (allergen_iter.next()) |allergen| {
            const entry = allergen_map.get(allergen);
            const idx = if (entry) |v| v else blk: {
                const new_idx = allergen_names.items.len;
                allergen_map.put(allergen, new_idx) catch unreachable;
                allergen_names.append(allocator, allergen) catch unreachable;
                break :blk new_idx;
            };
            allergens_mask |= @as(u64, 1) << @intCast(idx);
        }
        allergens_per_food.append(allocator, allergens_mask) catch unreachable;

        var ingredient_iter = std.mem.splitScalar(u8, ingredient_str, ' ');
        while (ingredient_iter.next()) |ingredient| {
            const entry = ingredient_map.get(ingredient);
            const idx = if (entry) |v| v else blk: {
                const new_idx = ingredient_list.items.len;
                ingredient_map.put(ingredient, new_idx) catch unreachable;
                ingredient_list.append(allocator, .{ .name = ingredient, .food_mask = 0, .count = 0, .candidates = 0 }) catch unreachable;
                break :blk new_idx;
            };
            ingredient_list.items[idx].food_mask |= @as(u64, 1) << @intCast(food_index);
            ingredient_list.items[idx].count += 1;
        }
    }

    const allergen_count = allergen_names.items.len;
    for (ingredient_list.items) |*ingredient| {
        var possible: u64 = 0;
        var impossible: u64 = 0;
        for (allergens_per_food.items, 0..) |mask, i| {
            if ((ingredient.food_mask & (@as(u64, 1) << @intCast(i))) == 0) {
                impossible |= mask;
            } else {
                possible |= mask;
            }
        }
        ingredient.candidates = possible & ~impossible;
    }

    var part1: usize = 0;
    for (ingredient_list.items) |ingredient| {
        if (ingredient.candidates == 0) part1 += ingredient.count;
    }

    const allergen_to_ingredient = try allocator.alloc(usize, allergen_count);
    @memset(allergen_to_ingredient, std.math.maxInt(usize));
    var resolved_mask: u64 = 0;

    var remaining = allergen_count;
    while (remaining > 0) {
        for (ingredient_list.items, 0..) |ingredient, i| {
            const candidates = ingredient.candidates & ~resolved_mask;
            if (candidates != 0 and (candidates & (candidates - 1)) == 0) {
                const allergen_idx = @as(usize, @intCast(@ctz(candidates)));
                if (allergen_to_ingredient[allergen_idx] == std.math.maxInt(usize)) {
                    allergen_to_ingredient[allergen_idx] = i;
                    resolved_mask |= candidates;
                    remaining -= 1;
                }
            }
        }
    }

    const order = try allocator.alloc(usize, allergen_count);
    for (order, 0..) |*slot, i| slot.* = i;
    std.mem.sort(usize, order, allergen_names.items, struct {
        fn lessThan(names: []const []const u8, a: usize, b: usize) bool {
            return std.mem.order(u8, names[a], names[b]).compare(.lt);
        }
    }.lessThan);

    var output = std.ArrayListUnmanaged([]const u8){};
    for (order) |idx| {
        const ingredient_idx = allergen_to_ingredient[idx];
        output.append(allocator, ingredient_list.items[ingredient_idx].name) catch unreachable;
    }
    const joined = std.mem.join(allocator, ",", output.items) catch unreachable;

    return .{ .p1 = part1, .p2 = joined };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(arena.allocator(), input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\n", .{result.p1});
    std.debug.print("Part 2: {s}\n", .{result.p2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
