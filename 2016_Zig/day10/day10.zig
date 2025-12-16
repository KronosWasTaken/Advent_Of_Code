const std = @import("std");
const Result = struct { p1: u32, p2: u32 };
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const result = solve(input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn old_main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();
    const input = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(input);
    var timer = try std.time.Timer.start();
    const result = try solve(input);
    const elapsed_us = @as(f64, @floatFromInt(timer.read())) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
fn solve(input: []const u8) Result {
    @setRuntimeSafety(false);
    var bots = [_]Bot{.{}} ** 256;
    var outputs = [_]u8{0} ** 256;
    var i: usize = 0;
    while (i < input.len) {
        const line_start = i;
        while (i < input.len and input[i] != '\n' and input[i] != '\r') : (i += 1) {}
        const line = input[line_start..i];
        while (i < input.len and (input[i] == '\n' or input[i] == '\r')) : (i += 1) {}
        if (std.mem.startsWith(u8, line, "value ")) {

            var j: usize = 6;
            var val: u8 = 0;
            while (j < line.len and line[j] >= '0' and line[j] <= '9') : (j += 1) {
                val = val * 10 + (line[j] - '0');
            }

            while (j < line.len and line[j] != 'b') : (j += 1) {}
            j += 4;
            var bot_id: u8 = 0;
            while (j < line.len and line[j] >= '0' and line[j] <= '9') : (j += 1) {
                bot_id = bot_id * 10 + (line[j] - '0');
            }
            bots[bot_id].give(val);
        } else if (std.mem.startsWith(u8, line, "bot ")) {

            var j: usize = 4;
            var bot_id: u8 = 0;
            while (j < line.len and line[j] >= '0' and line[j] <= '9') : (j += 1) {
                bot_id = bot_id * 10 + (line[j] - '0');
            }

            while (j < line.len and line[j] != 'l') : (j += 1) {}
            j += 7;
            const low_is_output = line[j] == 'o';
            j += if (low_is_output) 7 else 4;
            var low_dest: u8 = 0;
            while (j < line.len and line[j] >= '0' and line[j] <= '9') : (j += 1) {
                low_dest = low_dest * 10 + (line[j] - '0');
            }

            while (j < line.len and line[j] != 'h') : (j += 1) {}
            j += 8;
            const high_is_output = line[j] == 'o';
            j += if (high_is_output) 7 else 4;
            var high_dest: u8 = 0;
            while (j < line.len and line[j] >= '0' and line[j] <= '9') : (j += 1) {
                high_dest = high_dest * 10 + (line[j] - '0');
            }
            bots[bot_id].low_to = low_dest;
            bots[bot_id].high_to = high_dest;
            bots[bot_id].low_is_output = low_is_output;
            bots[bot_id].high_is_output = high_is_output;
        }
    }

    var p1: u32 = 0;
    var changed = true;
    while (changed) {
        changed = false;
        for (&bots, 0..) |*bot, id| {
            if (bot.count == 2) {
                const low = @min(bot.chips[0], bot.chips[1]);
                const high = @max(bot.chips[0], bot.chips[1]);
                if (low == 17 and high == 61) {
                    p1 = @intCast(id);
                }
                if (bot.low_is_output) {
                    outputs[bot.low_to] = low;
                } else {
                    bots[bot.low_to].give(low);
                }
                if (bot.high_is_output) {
                    outputs[bot.high_to] = high;
                } else {
                    bots[bot.high_to].give(high);
                }
                bot.count = 0;
                changed = true;
            }
        }
    }
    const p2 = @as(u32, outputs[0]) * @as(u32, outputs[1]) * @as(u32, outputs[2]);
    return .{ .p1 = p1, .p2 = p2 };
}
const Bot = struct {
    chips: [2]u8 = .{0, 0},
    count: u8 = 0,
    low_to: u8 = 0,
    high_to: u8 = 0,
    low_is_output: bool = false,
    high_is_output: bool = false,
    fn give(self: *Bot, chip: u8) void {
        if (self.count < 2) {
            self.chips[self.count] = chip;
            self.count += 1;
        }
    }
};
