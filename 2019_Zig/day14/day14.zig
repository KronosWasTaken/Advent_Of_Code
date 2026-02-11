const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

const Reagent = struct {
    chemical: []const u8,
    amount: u64,
};

const Reaction = struct {
    output: Reagent,
    inputs: std.ArrayList(Reagent),
};

fn parseNumber(s: []const u8) u64 {
    var num: u64 = 0;
    for (s) |c| {
        if (c >= '0' and c <= '9') {
            num = num * 10 + (c - '0');
        }
    }
    return num;
}

fn parseReagent(s: []const u8, allocator: std.mem.Allocator) !Reagent {
    const trimmed = std.mem.trim(u8, s, " ");
    var parts = std.mem.splitSequence(u8, trimmed, " ");
    const amount_str = parts.next() orelse return error.InvalidFormat;
    const chemical = parts.next() orelse return error.InvalidFormat;

    return Reagent{
        .chemical = try allocator.dupe(u8, chemical),
        .amount = parseNumber(amount_str),
    };
}

fn calculateOre(reactions: std.StringHashMap(Reaction), fuel_amount: u64, allocator: std.mem.Allocator) !u64 {
    var ore: u64 = 0;
    var inventory = std.StringHashMap(u64).init(allocator);
    defer inventory.deinit();

    var queue = try std.ArrayList(Reagent).initCapacity(allocator, 1000);
    defer queue.deinit(allocator);

    try queue.append(allocator, Reagent{
        .chemical = "FUEL",
        .amount = fuel_amount,
    });

    while (queue.items.len > 0) {
        const item = queue.orderedRemove(0);

        if (std.mem.eql(u8, item.chemical, "ORE")) {
            ore += item.amount;
        } else {
            const reaction = reactions.get(item.chemical) orelse continue;

            const inv_amount = inventory.get(item.chemical) orelse 0;
            const use_from_inventory = @min(item.amount, inv_amount);
            const needed = item.amount - use_from_inventory;

            if (inv_amount > 0) {
                try inventory.put(item.chemical, inv_amount - use_from_inventory);
            }

            if (needed > 0) {
                const multiplier = (needed + reaction.output.amount - 1) / reaction.output.amount;
                const produced = multiplier * reaction.output.amount;
                const leftover = produced - needed;

                try inventory.put(item.chemical, leftover);

                for (reaction.inputs.items) |reagent| {
                    try queue.append(allocator, Reagent{
                        .chemical = reagent.chemical,
                        .amount = reagent.amount * multiplier,
                    });
                }
            }
        }
    }

    return ore;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start_time = timer.read();


    var reactions = std.StringHashMap(Reaction).init(allocator);
    defer {
        var iter = reactions.keyIterator();
        while (iter.next()) |key| {
            allocator.free(key.*);
        }
        var val_iter = reactions.valueIterator();
        while (val_iter.next()) |val| {
            for (val.inputs.items) |reagent| {
                allocator.free(reagent.chemical);
            }
            val.inputs.deinit(allocator);
            allocator.free(val.output.chemical);
        }
        reactions.deinit();
    }

    var lines = std.mem.splitSequence(u8, input, "\n");
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var parts = std.mem.splitSequence(u8, line, " => ");
        const inputs_str = parts.next() orelse continue;
        const output_str_raw = parts.next() orelse continue;
        const output_str = std.mem.trim(u8, output_str_raw, " \r\n");

        const output = try parseReagent(output_str, allocator);

        var inputs = try std.ArrayList(Reagent).initCapacity(allocator, 10);
        var input_parts = std.mem.splitSequence(u8, inputs_str, ", ");
        while (input_parts.next()) |input_str| {
            const reagent = try parseReagent(input_str, allocator);
            try inputs.append(allocator, reagent);
        }

        try reactions.put(try allocator.dupe(u8, output.chemical), Reaction{
            .output = output,
            .inputs = inputs,
        });
    }


    const part1 = try calculateOre(reactions, 1, allocator);


    var start: u64 = 1;
    var end: u64 = 1_000_000_000_000;

    while (start != end) {
        const middle = (start + end + 1) / 2;
        const ore_needed = try calculateOre(reactions, middle, allocator);

        if (ore_needed > 1_000_000_000_000) {
            end = middle - 1;
        } else {
            start = middle;
        }
    }

    const part2 = start;

    const elapsed_ns = timer.read() - start_time;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;

    std.debug.print("Part 1: {}\n", .{part1});
    std.debug.print("Part 2: {}\n", .{part2});
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
