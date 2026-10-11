const std = @import("std");

const ELEMENTS_DATA =
    "22 -> H -> H\n" ++
    "13112221133211322112211213322112 -> He -> Hf Pa H Ca Li\n" ++
    "312211322212221121123222112 -> Li -> He\n" ++
    "111312211312113221133211322112211213322112 -> Be -> Ge Ca Li\n" ++
    "1321132122211322212221121123222112 -> B -> Be\n" ++
    "3113112211322112211213322112 -> C -> B\n" ++
    "111312212221121123222112 -> N -> C\n" ++
    "132112211213322112 -> O -> N\n" ++
    "31121123222112 -> F -> O\n" ++
    "111213322112 -> Ne -> F\n" ++
    "123222112 -> Na -> Ne\n" ++
    "3113322112 -> Mg -> Pm Na\n" ++
    "1113222112 -> Al -> Mg\n" ++
    "1322112 -> Si -> Al\n" ++
    "311311222112 -> P -> Ho Si\n" ++
    "1113122112 -> S -> P\n" ++
    "132112 -> Cl -> S\n" ++
    "3112 -> Ar -> Cl\n" ++
    "1112 -> K -> Ar\n" ++
    "12 -> Ca -> K\n" ++
    "3113112221133112 -> Sc -> Ho Pa H Ca Co\n" ++
    "11131221131112 -> Ti -> Sc\n" ++
    "13211312 -> V -> Ti\n" ++
    "31132 -> Cr -> V\n" ++
    "111311222112 -> Mn -> Cr Si\n" ++
    "13122112 -> Fe -> Mn\n" ++
    "32112 -> Co -> Fe\n" ++
    "11133112 -> Ni -> Zn Co\n" ++
    "131112 -> Cu -> Ni\n" ++
    "312 -> Zn -> Cu\n" ++
    "13221133122211332 -> Ga -> Eu Ca Ac H Ca Zn\n" ++
    "31131122211311122113222 -> Ge -> Ho Ga\n" ++
    "11131221131211322113322112 -> As -> Ge Na\n" ++
    "13211321222113222112 -> Se -> As\n" ++
    "3113112211322112 -> Br -> Se\n" ++
    "11131221222112 -> Kr -> Br\n" ++
    "1321122112 -> Rb -> Kr\n" ++
    "3112112 -> Sr -> Rb\n" ++
    "1112133 -> Y -> Sr U\n" ++
    "12322211331222113112211 -> Zr -> Y H Ca Tc\n" ++
    "1113122113322113111221131221 -> Nb -> Er Zr\n" ++
    "13211322211312113211 -> Mo -> Nb\n" ++
    "311322113212221 -> Tc -> Mo\n" ++
    "132211331222113112211 -> Ru -> Eu Ca Tc\n" ++
    "311311222113111221131221 -> Rh -> Ho Ru\n" ++
    "111312211312113211 -> Pd -> Rh\n" ++
    "132113212221 -> Ag -> Pd\n" ++
    "3113112211 -> Cd -> Ag\n" ++
    "11131221 -> In -> Cd\n" ++
    "13211 -> Sn -> In\n" ++
    "3112221 -> Sb -> Pm Sn\n" ++
    "1322113312211 -> Te -> Eu Ca Sb\n" ++
    "311311222113111221 -> I -> Ho Te\n" ++
    "11131221131211 -> Xe -> I\n" ++
    "13211321 -> Cs -> Xe\n" ++
    "311311 -> Ba -> Cs\n" ++
    "11131 -> La -> Ba\n" ++
    "1321133112 -> Ce -> La H Ca Co\n" ++
    "31131112 -> Pr -> Ce\n" ++
    "111312 -> Nd -> Pr\n" ++
    "132 -> Pm -> Nd\n" ++
    "311332 -> Sm -> Pm Ca Zn\n" ++
    "1113222 -> Eu -> Sm\n" ++
    "13221133112 -> Gd -> Eu Ca Co\n" ++
    "3113112221131112 -> Tb -> Ho Gd\n" ++
    "111312211312 -> Dy -> Tb\n" ++
    "1321132 -> Ho -> Dy\n" ++
    "311311222 -> Er -> Ho Pm\n" ++
    "11131221133112 -> Tm -> Er Ca Co\n" ++
    "1321131112 -> Yb -> Tm\n" ++
    "311312 -> Lu -> Yb\n" ++
    "11132 -> Hf -> Lu\n" ++
    "13112221133211322112211213322113 -> Ta -> Hf Pa H Ca W\n" ++
    "312211322212221121123222113 -> W -> Ta\n" ++
    "111312211312113221133211322112211213322113 -> Re -> Ge Ca W\n" ++
    "1321132122211322212221121123222113 -> Os -> Re\n" ++
    "3113112211322112211213322113 -> Ir -> Os\n" ++
    "111312212221121123222113 -> Pt -> Ir\n" ++
    "132112211213322113 -> Au -> Pt\n" ++
    "31121123222113 -> Hg -> Au\n" ++
    "111213322113 -> Tl -> Hg\n" ++
    "123222113 -> Pb -> Tl\n" ++
    "3113322113 -> Bi -> Pm Pb\n" ++
    "1113222113 -> Po -> Bi\n" ++
    "1322113 -> At -> Po\n" ++
    "311311222113 -> Rn -> Ho At\n" ++
    "1113122113 -> Fr -> Rn\n" ++
    "132113 -> Ra -> Fr\n" ++
    "3113 -> Ac -> Ra\n" ++
    "1113 -> Th -> Ac\n" ++
    "13 -> Pa -> Th\n" ++
    "3 -> U -> Pa";

const ElementInfo = struct {
    seq: []const u8,
    name: []const u8,
    decays: [6]u8,
    decay_count: u8,
    len: usize,
};

const Model = blk: {
    @setEvalBranchQuota(100000);
    var elements: [92]ElementInfo = undefined;
    var lines_it = std.mem.tokenizeScalar(u8, ELEMENTS_DATA, '\n');
    var idx: usize = 0;

    // First pass: extract names and sequences
    while (lines_it.next()) |line| {
        var arrow_it = std.mem.splitSequence(u8, line, " -> ");
        const seq = arrow_it.next().?;
        const name = arrow_it.next().?;
        elements[idx] = .{
            .seq = seq,
            .name = name,
            .decays = undefined,
            .decay_count = 0,
            .len = seq.len,
        };
        idx += 1;
    }

    // Helper to find element index by name
    const findByName = struct {
        fn get(list: []const ElementInfo, n: []const u8) u8 {
            for (list, 0..) |elem, i| {
                if (std.mem.eql(u8, elem.name, n)) return @intCast(i);
            }
            unreachable;
        }
    }.get;

    // Second pass: parse decay products
    var lines_it2 = std.mem.tokenizeScalar(u8, ELEMENTS_DATA, '\n');
    idx = 0;
    while (lines_it2.next()) |line| {
        var arrow_it = std.mem.splitSequence(u8, line, " -> ");
        _ = arrow_it.next();
        _ = arrow_it.next();
        const decays_str = arrow_it.next().?;
        var prod_it = std.mem.tokenizeScalar(u8, decays_str, ' ');
        var d_cnt: u8 = 0;
        while (prod_it.next()) |prod| {
            elements[idx].decays[d_cnt] = findByName(&elements, prod);
            d_cnt += 1;
        }
        elements[idx].decay_count = d_cnt;
        idx += 1;
    }

    break :blk elements;
};

inline fn solve(input: []const u8) struct { p1: usize, p2: usize } {
    @setRuntimeSafety(false);
    const trimmed = std.mem.trim(u8, input, " \r\n\t");

    var current = [_]usize{0} ** 92;
    inline for (Model, 0..) |elem, i| {
        if (std.mem.eql(u8, elem.seq, trimmed)) {
            current[i] = 1;
        }
    }

    // Step 40 times for part 1
    for (0..40) |_| {
        var next = [_]usize{0} ** 92;
        inline for (Model, 0..) |elem, i| {
            const cnt = current[i];
            if (cnt > 0) {
                inline for (0..elem.decay_count) |d_idx| {
                    next[elem.decays[d_idx]] += cnt;
                }
            }
        }
        current = next;
    }

    var p1: usize = 0;
    inline for (Model, 0..) |elem, i| {
        p1 += current[i] * elem.len;
    }

    // Step 10 more times for part 2
    for (0..10) |_| {
        var next = [_]usize{0} ** 92;
        inline for (Model, 0..) |elem, i| {
            const cnt = current[i];
            if (cnt > 0) {
                inline for (0..elem.decay_count) |d_idx| {
                    next[elem.decays[d_idx]] += cnt;
                }
            }
        }
        current = next;
    }

    var p2: usize = 0;
    inline for (Model, 0..) |elem, i| {
        p2 += current[i] * elem.len;
    }

    return .{ .p1 = p1, .p2 = p2 };
}

pub fn main() !void {
    const input = "1113122113";
    var timer = try std.time.Timer.start();
    const start = timer.read();
    const result = solve(input);
    const elapsed_ns = timer.read() - start;
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    std.debug.print("Part 1: {}\nPart 2: {}\n", .{ result.p1, result.p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{elapsed_us});
}
