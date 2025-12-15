const std = @import("std");
const Ing = struct { cap: i8, dur: i8, flav: i8, tex: i8, cal: i8 };
fn parse(input: []const u8, ing: []Ing) u8 {
    var cnt: u8 = 0;
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        var parts = std.mem.tokenizeAny(u8, line, " :,");
        _ = parts.next(); // name
        _ = parts.next(); // "capacity"
        const cap = std.fmt.parseInt(i8, parts.next().?, 10) catch 0;
        _ = parts.next(); // "durability"
        const dur = std.fmt.parseInt(i8, parts.next().?, 10) catch 0;
        _ = parts.next(); // "flavor"
        const flav = std.fmt.parseInt(i8, parts.next().?, 10) catch 0;
        _ = parts.next(); // "texture"
        const tex = std.fmt.parseInt(i8, parts.next().?, 10) catch 0;
        _ = parts.next(); // "calories"
        const cal = std.fmt.parseInt(i8, parts.next().?, 10) catch 0;
        ing[cnt] = .{ .cap = cap, .dur = dur, .flav = flav, .tex = tex, .cal = cal };
        cnt += 1;
    }
    return cnt;
}
fn solve(input: []const u8) struct { p1: i64, p2: i64 } {
    @setRuntimeSafety(false);
    var ing: [4]Ing = undefined;
    _ = parse(input, &ing);
    var p1: i64 = 0;
    var p2: i64 = 0;
    const i2_cap = ing[2].cap;
    const i2_dur = ing[2].dur;
    const i2_flav = ing[2].flav;
    const i2_tex = ing[2].tex;
    const i2_cal = ing[2].cal;
    const i3_cap = ing[3].cap;
    const i3_dur = ing[3].dur;
    const i3_flav = ing[3].flav;
    const i3_tex = ing[3].tex;
    const i3_cal = ing[3].cal;
    const diff_cap = i2_cap - i3_cap;
    const diff_dur = i2_dur - i3_dur;
    const diff_flav = i2_flav - i3_flav;
    const diff_tex = i2_tex - i3_tex;
    const diff_cal = i2_cal - i3_cal;
    var a: u8 = 0;
    while (a <= 100) : (a += 1) {
        const a_cap = @as(i32, ing[0].cap) * a;
        const a_dur = @as(i32, ing[0].dur) * a;
        const a_flav = @as(i32, ing[0].flav) * a;
        const a_tex = @as(i32, ing[0].tex) * a;
        const a_cal = @as(i32, ing[0].cal) * a;
        var b: u8 = 0;
        const b_max = 100 - a;
        while (b <= b_max) : (b += 1) {
            const ab_cap = a_cap + @as(i32, ing[1].cap) * b;
            const ab_dur = a_dur + @as(i32, ing[1].dur) * b;
            const ab_flav = a_flav + @as(i32, ing[1].flav) * b;
            const ab_tex = a_tex + @as(i32, ing[1].tex) * b;
            const ab_cal = a_cal + @as(i32, ing[1].cal) * b;
            const c_max = b_max - b;
            var cap = ab_cap + @as(i32, i3_cap) * c_max;
            var dur = ab_dur + @as(i32, i3_dur) * c_max;
            var flav = ab_flav + @as(i32, i3_flav) * c_max;
            var tex = ab_tex + @as(i32, i3_tex) * c_max;
            var cal = ab_cal + @as(i32, i3_cal) * c_max;
            var c: u8 = 0;
            while (c <= c_max) : (c += 1) {
                const valid = @intFromBool(cap > 0) & @intFromBool(dur > 0) & 
                              @intFromBool(flav > 0) & @intFromBool(tex > 0);
                if (valid != 0) {
                    const s = @as(i64, cap) * dur * flav * tex;
                    p1 = @max(p1, s);
                    const is_500 = @intFromBool(cal == 500);
                    p2 = if (is_500 != 0) @max(p2, s) else p2;
                }
                cap += diff_cap;
                dur += diff_dur;
                flav += diff_flav;
                tex += diff_tex;
                cal += diff_cal;
            }
        }
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
    std.debug.print("Part 1: {} | Part 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
