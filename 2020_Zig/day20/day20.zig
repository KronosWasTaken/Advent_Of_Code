const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u32,
};

const Tile = struct {
    id: u64,
    top: [8]u16,
    left: [8]u16,
    bottom: [8]u16,
    right: [8]u16,
    pixels: [10][10]u8,

    const coefficients: [8][6]i8 = .{
        .{ 1, 0, 1, 0, 1, 1 },
        .{ -1, 0, 8, 0, 1, 1 },
        .{ 1, 0, 1, 0, -1, 8 },
        .{ -1, 0, 8, 0, -1, 8 },
        .{ 0, 1, 1, -1, 0, 8 },
        .{ 0, 1, 1, 1, 0, 1 },
        .{ 0, -1, 8, -1, 0, 8 },
        .{ 0, -1, 8, 1, 0, 1 },
    };

    fn transform(self: *const Tile, image: []u128, permutation: usize) void {
        const coeff = coefficients[permutation];
        const a: i8 = coeff[0];
        const b: i8 = coeff[1];
        const c: i8 = coeff[2];
        const d: i8 = coeff[3];
        const e: i8 = coeff[4];
        const f: i8 = coeff[5];

        var row: usize = 0;
        while (row < 8) : (row += 1) {
            var acc: u128 = 0;
            var col: usize = 0;
            while (col < 8) : (col += 1) {
                const x = @as(i8, @intCast(col)) * a + @as(i8, @intCast(row)) * b + c;
                const y = @as(i8, @intCast(col)) * d + @as(i8, @intCast(row)) * e + f;
                const bit = self.pixels[@intCast(y)][@intCast(x)] & 1;
                acc = (acc << 1) | bit;
            }
            image[row] = (image[row] << 8) | acc;
        }
    }
};

fn reverseBits10(v: u16) u16 {
    var r: u16 = 0;
    var i: u8 = 0;
    while (i < 10) : (i += 1) {
        r = (r << 1) | ((v >> @as(u4, @intCast(i))) & 1);
    }
    return r;
}

fn parseTiles(input: []const u8, tiles: *std.ArrayListUnmanaged(Tile), allocator: std.mem.Allocator) !void {
    var clean = std.ArrayListUnmanaged(u8){};
    defer clean.deinit(allocator);
    for (input) |ch| {
        if (ch != '\r') try clean.append(allocator, ch);
    }

    var groups = std.mem.splitSequence(u8, clean.items, "\n\n");
    while (groups.next()) |group| {
        if (group.len == 0) continue;
        var lines = std.mem.splitScalar(u8, group, '\n');
        const title = lines.next().?;
        const tile_id = try std.fmt.parseInt(u64, title[5 .. title.len - 1], 10);

        var tile = Tile{
            .id = tile_id,
            .top = undefined,
            .left = undefined,
            .bottom = undefined,
            .right = undefined,
            .pixels = undefined,
        };

        var row: usize = 0;
        while (row < 10) : (row += 1) {
            const line = lines.next().?;
            var col: usize = 0;
            while (col < 10) : (col += 1) {
                tile.pixels[row][col] = line[col];
            }
        }

        var top: u16 = 0;
        var left: u16 = 0;
        var bottom: u16 = 0;
        var right: u16 = 0;
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            top = (top << 1) | (tile.pixels[0][i] & 1);
            left = (left << 1) | (tile.pixels[i][0] & 1);
            bottom = (bottom << 1) | (tile.pixels[9][i] & 1);
            right = (right << 1) | (tile.pixels[i][9] & 1);
        }

        const rt = reverseBits10(top);
        const rl = reverseBits10(left);
        const rb = reverseBits10(bottom);
        const rr = reverseBits10(right);

        tile.top = .{ top, rt, bottom, rb, rl, left, rr, right };
        tile.left = .{ left, right, rl, rr, bottom, top, rb, rt };
        tile.bottom = .{ bottom, rb, top, rt, rr, right, rl, left };
        tile.right = .{ right, left, rr, rl, top, bottom, rt, rb };

        try tiles.append(allocator, tile);
    }
}

fn findPermutation(edges: [8]u16, edge: u16) usize {
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        if (edges[i] == edge) return i;
    }
    unreachable;
}

fn findCornerEdge(tiles: []const Tile, frequency: *[1024]u8) u16 {
    for (tiles) |tile| {
        var i: usize = 0;
        while (i < 8) : (i += 1) {
            if (frequency[tile.top[i]] == 1 and frequency[tile.left[i]] == 1) {
                frequency[tile.top[i]] += 1;
                return tile.top[i];
            }
        }
    }
    unreachable;
}

fn solve(input: []const u8) Result {
    var tiles = std.ArrayListUnmanaged(Tile){};
    defer tiles.deinit(std.heap.page_allocator);
    parseTiles(input, &tiles, std.heap.page_allocator) catch unreachable;

    var frequency: [1024]u8 = [_]u8{0} ** 1024;
    for (tiles.items) |tile| {
        for (tile.top) |edge| {
            frequency[edge] += 1;
        }
    }

    var part1: u64 = 1;
    for (tiles.items) |tile| {
        const total = frequency[tile.top[0]] + frequency[tile.left[0]] + frequency[tile.bottom[0]] + frequency[tile.right[0]];
        if (total == 6) part1 *= tile.id;
    }

    var edge_to_tile: [1024][2]u16 = [_][2]u16{.{ 0, 0 }} ** 1024;
    var edge_counts: [1024]u8 = [_]u8{0} ** 1024;
    const placed = std.heap.page_allocator.alloc(bool, tiles.items.len) catch unreachable;
    defer std.heap.page_allocator.free(placed);
    @memset(placed, false);

    var i: usize = 0;
    while (i < tiles.items.len) : (i += 1) {
        const tile = tiles.items[i];
        for (tile.top) |edge| {
            const count = edge_counts[edge];
            edge_to_tile[edge][count] = @intCast(i);
            edge_counts[edge] = count + 1;
        }
    }

    const find_matching_tile = struct {
        fn f(edge: u16, edge_map: *const [1024][2]u16, placed_flags: []bool, tiles_slice: []const Tile) *const Tile {
            const first = edge_map[edge][0];
            const second = edge_map[edge][1];
            const next_index: u16 = if (placed_flags[first]) second else first;
            placed_flags[next_index] = true;
            return &tiles_slice[next_index];
        }
    }.f;

    const corner_edge = findCornerEdge(tiles.items, &edge_counts);
    var next_top: u16 = corner_edge;

    var image: [96]u128 = [_]u128{0} ** 96;
    var index: usize = 0;

    while (edge_counts[next_top] == 2) {
        const tile = find_matching_tile(next_top, &edge_to_tile, placed, tiles.items);
        const permutation = findPermutation(tile.top, next_top);
        tile.transform(image[index..], permutation);
        next_top = tile.bottom[permutation];

        var next_left = tile.right[permutation];
        while (edge_counts[next_left] == 2) {
            const row_tile = find_matching_tile(next_left, &edge_to_tile, placed, tiles.items);
            const row_perm = findPermutation(row_tile.left, next_left);
            row_tile.transform(image[index..], row_perm);
            next_left = row_tile.right[row_perm];
        }

        index += 8;
    }

    var sea: u32 = 0;
    for (image) |row| {
        sea += @popCount(row);
    }

    const findMonsters = struct {
        fn f(image_data: []const u128, monster: []u128, width: usize, height: usize, sea_count: u32) ?u32 {
            var rough = sea_count;
            var shift: usize = 0;
            while (shift < (96 - width + 1)) : (shift += 1) {
                var start: usize = 0;
                while (start + height <= image_data.len) : (start += 1) {
                    var matches = true;
                    var row: usize = 0;
                    while (row < height) : (row += 1) {
                        if ((monster[row] & image_data[start + row]) != monster[row]) {
                            matches = false;
                            break;
                        }
                    }
                    if (matches) rough -= 15;
                }
                var m: usize = 0;
                while (m < height) : (m += 1) {
                    monster[m] <<= 1;
                }
            }
            if (rough < sea_count) return rough;
            return null;
        }
    }.f;

    var part2: u32 = 0;
    var monsters1 = [_][3]u128{
        .{ 0b00000000000000000010, 0b10000110000110000111, 0b01001001001001001000 },
        .{ 0b01001001001001001000, 0b10000110000110000111, 0b00000000000000000010 },
        .{ 0b01000000000000000000, 0b11100001100001100001, 0b00010010010010010010 },
        .{ 0b00010010010010010010, 0b11100001100001100001, 0b01000000000000000000 },
    };

    for (&monsters1) |*monster| {
        if (findMonsters(&image, monster, 20, 3, sea)) |rough| {
            part2 = rough;
            break;
        }
    }

    if (part2 == 0) {
        var monsters2 = [_][20]u128{
            .{ 2, 4, 0, 0, 4, 2, 2, 4, 0, 0, 4, 2, 2, 4, 0, 0, 4, 2, 3, 2 },
            .{ 2, 3, 2, 4, 0, 0, 4, 2, 2, 4, 0, 0, 4, 2, 2, 4, 0, 0, 4, 2 },
            .{ 2, 1, 0, 0, 1, 2, 2, 1, 0, 0, 1, 2, 2, 1, 0, 0, 1, 2, 6, 2 },
            .{ 2, 6, 2, 1, 0, 0, 1, 2, 2, 1, 0, 0, 1, 2, 2, 1, 0, 0, 1, 2 },
        };

        for (&monsters2) |*monster| {
            if (findMonsters(&image, monster, 3, 20, sea)) |rough| {
                part2 = rough;
                break;
            }
        }
    }

    return .{ .p1 = part1, .p2 = part2 };
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
