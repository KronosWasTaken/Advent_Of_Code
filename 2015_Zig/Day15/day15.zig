const std = @import("std");

const Ing = struct {
    cap: i32,
    dur: i32,
    flav: i32,
    tex: i32,
    cal: i32,
};

inline fn solve(input: []const u8) struct { p1: i64, p2: i64 } {
    @setRuntimeSafety(false);
    var ing: [4]Ing = undefined;
    var count: usize = 0;

    var i: usize = 0;
    while (i < input.len and count < 4) {
        var vals: [5]i32 = undefined;
        var v_idx: usize = 0;
        while (i < input.len and input[i] != '\n' and v_idx < 5) {
            if (input[i] == '-' or (input[i] >= '0' and input[i] <= '9')) {
                const neg = input[i] == '-';
                if (neg) i += 1;
                var num: i32 = 0;
                while (i < input.len and input[i] >= '0' and input[i] <= '9') : (i += 1) {
                    num = num * 10 + (input[i] - '0');
                }
                vals[v_idx] = if (neg) -num else num;
                v_idx += 1;
            } else {
                i += 1;
            }
        }
        ing[count] = .{
            .cap = vals[0],
            .dur = vals[1],
            .flav = vals[2],
            .tex = vals[3],
            .cal = vals[4],
        };
        count += 1;
        while (i < input.len and input[i] != '\n') : (i += 1) {}
        if (i < input.len and input[i] == '\n') i += 1;
    }

    var p1: i64 = 0;
    var p2: i64 = 0;

    const max_cap23 = @max(ing[2].cap, ing[3].cap);
    const max_dur23 = @max(ing[2].dur, ing[3].dur);
    const max_flav23 = @max(ing[2].flav, ing[3].flav);
    const max_tex23 = @max(ing[2].tex, ing[3].tex);

    const diff_cap = ing[2].cap - ing[3].cap;
    const diff_dur = ing[2].dur - ing[3].dur;
    const diff_flav = ing[2].flav - ing[3].flav;
    const diff_tex = ing[2].tex - ing[3].tex;
    const diff_cal = ing[2].cal - ing[3].cal;

    var a: i32 = 0;
    while (a <= 100) : (a += 1) {
        const a_cap = ing[0].cap * a;
        const a_dur = ing[0].dur * a;
        const a_flav = ing[0].flav * a;
        const a_tex = ing[0].tex * a;
        const a_cal = ing[0].cal * a;

        var b: i32 = 0;
        const b_max = 100 - a;
        while (b <= b_max) : (b += 1) {
            const ab_cap = a_cap + ing[1].cap * b;
            const ab_dur = a_dur + ing[1].dur * b;
            const ab_flav = a_flav + ing[1].flav * b;
            const ab_tex = a_tex + ing[1].tex * b;
            const ab_cal = a_cal + ing[1].cal * b;

            const rem = b_max - b;
            if (ab_cap + max_cap23 * rem <= 0 or
                ab_dur + max_dur23 * rem <= 0 or
                ab_flav + max_flav23 * rem <= 0 or
                ab_tex + max_tex23 * rem <= 0)
            {
                continue;
            }

            const init_cap = ab_cap + ing[3].cap * rem;
            const init_dur = ab_dur + ing[3].dur * rem;
            const init_flav = ab_flav + ing[3].flav * rem;
            const init_tex = ab_tex + ing[3].tex * rem;
            const init_cal = ab_cal + ing[3].cal * rem;

            // Compute c_min and c_max analytically
            var c_min: i32 = 0;
            var c_max: i32 = rem;

            // cap > 0
            if (diff_cap > 0) {
                c_min = @max(c_min, @divFloor(-init_cap, diff_cap) + 1);
            } else if (diff_cap < 0) {
                c_max = @min(c_max, @divFloor(init_cap - 1, -diff_cap));
            } else if (init_cap <= 0) continue;

            // dur > 0
            if (diff_dur > 0) {
                c_min = @max(c_min, @divFloor(-init_dur, diff_dur) + 1);
            } else if (diff_dur < 0) {
                c_max = @min(c_max, @divFloor(init_dur - 1, -diff_dur));
            } else if (init_dur <= 0) continue;

            // flav > 0
            if (diff_flav > 0) {
                c_min = @max(c_min, @divFloor(-init_flav, diff_flav) + 1);
            } else if (diff_flav < 0) {
                c_max = @min(c_max, @divFloor(init_flav - 1, -diff_flav));
            } else if (init_flav <= 0) continue;

            // tex > 0
            if (diff_tex > 0) {
                c_min = @max(c_min, @divFloor(-init_tex, diff_tex) + 1);
            } else if (diff_tex < 0) {
                c_max = @min(c_max, @divFloor(init_tex - 1, -diff_tex));
            } else if (init_tex <= 0) continue;

            if (c_min > c_max) continue;

            // Part 2: O(1) exact solution
            if (diff_cal != 0) {
                const req = 500 - init_cal;
                if (@rem(req, diff_cal) == 0) {
                    const c2 = @divExact(req, diff_cal);
                    if (c2 >= c_min and c2 <= c_max) {
                        const cap2 = init_cap + c2 * diff_cap;
                        const dur2 = init_dur + c2 * diff_dur;
                        const flav2 = init_flav + c2 * diff_flav;
                        const tex2 = init_tex + c2 * diff_tex;
                        const score2 = @as(i64, cap2) * dur2 * flav2 * tex2;
                        p2 = @max(p2, score2);
                    }
                }
            } else if (init_cal == 500) {
                // If diff_cal == 0 and cal is 500, all c in [c_min, c_max] have 500 cal
                // so p2 will equal p1 for this branch
            }

            // Part 1: iterate only over valid c
            var cap = init_cap + c_min * diff_cap;
            var dur = init_dur + c_min * diff_dur;
            var flav = init_flav + c_min * diff_flav;
            var tex = init_tex + c_min * diff_tex;

            var c = c_min;
            while (c <= c_max) : (c += 1) {
                const score = @as(i64, cap) * dur * flav * tex;
                p1 = @max(p1, score);
                cap += diff_cap;
                dur += diff_dur;
                flav += diff_flav;
                tex += diff_tex;
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
