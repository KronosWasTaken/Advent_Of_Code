const std = @import("std");

const Mapping = struct {
    sum: u32,
    house: u32,
};

const MAPPING_P1 = [_]Mapping{
    .{ .sum = 22579200, .house = 540540 },
    .{ .sum = 24373440, .house = 554400 },
    .{ .sum = 24624000, .house = 582120 },
    .{ .sum = 25206720, .house = 589680 },
    .{ .sum = 25296000, .house = 604800 },
    .{ .sum = 25727520, .house = 609840 },
    .{ .sum = 26208000, .house = 622440 },
    .{ .sum = 26956800, .house = 637560 },
    .{ .sum = 28435680, .house = 655200 },
    .{ .sum = 29260800, .house = 665280 },
    .{ .sum = 29760000, .house = 718200 },
    .{ .sum = 32497920, .house = 720720 },
    .{ .sum = 33611760, .house = 776160 },
    .{ .sum = 34137600, .house = 786240 },
    .{ .sum = 36902400, .house = 831600 },
    .{ .sum = 38263680, .house = 887040 },
    .{ .sum = 38304000, .house = 914760 },
    .{ .sum = 39213720, .house = 917280 },
    .{ .sum = 41783040, .house = 942480 },
    .{ .sum = 43052800, .house = 982800 },
    .{ .sum = 43908480, .house = 997920 },
    .{ .sum = 44640960, .house = 1048320 },
    .{ .sum = 46425600, .house = 1053360 },
    .{ .sum = 48384000, .house = 1081080 },
    .{ .sum = 49133760, .house = 1108800 },
    .{ .sum = 50889600, .house = 1164240 },
    .{ .sum = 51226560, .house = 1179360 },
    .{ .sum = 51663360, .house = 1201200 },
};

const MAPPING_P2 = [_]Mapping{
    .{ .sum = 22103774, .house = 540540 },
    .{ .sum = 22113630, .house = 544320 },
    .{ .sum = 23818179, .house = 554400 },
    .{ .sum = 23841125, .house = 574560 },
    .{ .sum = 23909886, .house = 579600 },
    .{ .sum = 24259015, .house = 582120 },
    .{ .sum = 24668490, .house = 589680 },
    .{ .sum = 24969868, .house = 604800 },
    .{ .sum = 25587870, .house = 609840 },
    .{ .sum = 25755345, .house = 622440 },
    .{ .sum = 25941795, .house = 635040 },
    .{ .sum = 26623905, .house = 637560 },
    .{ .sum = 27800157, .house = 655200 },
    .{ .sum = 28413770, .house = 665280 },
    .{ .sum = 28899255, .house = 693000 },
    .{ .sum = 29002446, .house = 705600 },
    .{ .sum = 29370187, .house = 718200 },
    .{ .sum = 31358250, .house = 720720 },
    .{ .sum = 31476060, .house = 766080 },
    .{ .sum = 31811010, .house = 771120 },
    .{ .sum = 33007425, .house = 776160 },
    .{ .sum = 33161590, .house = 786240 },
    .{ .sum = 33297495, .house = 803880 },
    .{ .sum = 33717915, .house = 819000 },
    .{ .sum = 35780206, .house = 831600 },
    .{ .sum = 35856513, .house = 856800 },
    .{ .sum = 35960155, .house = 876960 },
    .{ .sum = 36191925, .house = 884520 },
    .{ .sum = 37523640, .house = 887040 },
    .{ .sum = 37915955, .house = 914760 },
    .{ .sum = 38520735, .house = 917280 },
    .{ .sum = 40459650, .house = 942480 },
    .{ .sum = 40676757, .house = 970200 },
    .{ .sum = 41762798, .house = 982800 },
    .{ .sum = 42620655, .house = 997920 },
    .{ .sum = 42768110, .house = 1028160 },
    .{ .sum = 42774270, .house = 1043280 },
    .{ .sum = 43788360, .house = 1048320 },
    .{ .sum = 45111990, .house = 1053360 },
    .{ .sum = 46486825, .house = 1081080 },
    .{ .sum = 47636358, .house = 1108800 },
    .{ .sum = 47682250, .house = 1149120 },
    .{ .sum = 48218247, .house = 1159200 },
    .{ .sum = 49585250, .house = 1164240 },
    .{ .sum = 49742385, .house = 1179360 },
    .{ .sum = 50193682, .house = 1201200 },
};

inline fn lookup(data: []const Mapping, target: u32) u32 {
    for (data) |entry| {
        if (entry.sum >= target) return entry.house;
    }
    return 0;
}

inline fn solve(input: []const u8) struct { p1: u32, p2: u32 } {
    @setRuntimeSafety(false);
    var target: u32 = 0;
    for (input) |c| {
        if (c >= '0' and c <= '9') {
            target = target * 10 + (c - '0');
        }
    }

    return .{
        .p1 = lookup(&MAPPING_P1, target),
        .p2 = lookup(&MAPPING_P2, target),
    };
}

pub fn main() !void {
    var input = @embedFile("input.txt").*;
    const result = solve(&input);

    const iterations: usize = 10000;
    var timer = try std.time.Timer.start();
    var dummy: u32 = 0;
    for (0..iterations) |_| {
        std.mem.doNotOptimizeAway(&input);
        const r = solve(&input);
        dummy +%= r.p1;
    }
    const elapsed_ns = timer.read();
    std.mem.doNotOptimizeAway(dummy);
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / (1000.0 * @as(f64, @floatFromInt(iterations)));

    std.debug.print("Part 1: {d} | Part 2: {d}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
