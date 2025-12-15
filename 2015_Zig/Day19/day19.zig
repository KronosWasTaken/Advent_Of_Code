const std = @import("std");
const Replacement = struct {
    from: []const u8,
    to: []const u8,
};
fn solve(input: []const u8) !struct { p1: u32, p2: u32 } {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var replacements_buf: [50]Replacement = undefined;
    var rep_count: usize = 0;
    var molecule: []const u8 = "";
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.indexOf(u8, line, " => ")) |idx| {
            const from = line[0..idx];
            const to = line[idx + 4..];
            replacements_buf[rep_count] = .{ .from = from, .to = to };
            rep_count += 1;
        } else {
            molecule = line;
        }
    }
    const replacements = replacements_buf[0..rep_count];
    var distinct = std.StringHashMap(void).init(allocator);
    var buffer: [600]u8 = undefined;
    for (replacements) |rep| {
        var pos: usize = 0;
        while (pos <= molecule.len - rep.from.len) : (pos += 1) {
            if (std.mem.eql(u8, molecule[pos..pos + rep.from.len], rep.from)) {
                const new_len = molecule.len - rep.from.len + rep.to.len;
                @memcpy(buffer[0..pos], molecule[0..pos]);
                @memcpy(buffer[pos..pos + rep.to.len], rep.to);
                @memcpy(buffer[pos + rep.to.len..new_len], molecule[pos + rep.from.len..]);
                const key = try allocator.dupe(u8, buffer[0..new_len]);
                try distinct.put(key, {});
            }
        }
    }
    const p1: u32 = @intCast(distinct.count());
    var total: u32 = 0;
    var rn_count: u32 = 0;
    var ar_count: u32 = 0;
    var y_count: u32 = 0;
    var i: usize = 0;
    while (i < molecule.len) {
        if (i + 1 < molecule.len) {
            const two = molecule[i..i+2];
            if (std.mem.eql(u8, two, "Rn")) {
                rn_count += 1;
                total += 1;
                i += 2;
                continue;
            } else if (std.mem.eql(u8, two, "Ar")) {
                ar_count += 1;
                total += 1;
                i += 2;
                continue;
            }
        }
        if (molecule[i] >= 'A' and molecule[i] <= 'Z') {
            if (molecule[i] == 'Y') {
                y_count += 1;
            }
            total += 1;
        }
        i += 1;
    }
    const p2 = total - rn_count - ar_count - 2 * y_count - 1;
    return .{ .p1 = p1, .p2 = p2 };
}
pub fn main() !void {
    const input = @embedFile("input.txt");
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = try solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
