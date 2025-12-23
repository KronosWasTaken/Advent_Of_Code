const std = @import("std");

const Result = struct { p1: u32, p2: u32 };

const Claim = struct {
    id: u16,
    y: u16,
    h: u16,
    idx: u8,
    mask0: u64,
    mask1: u64,
    part2: bool,
    
    fn lessThan(_: void, a: Claim, b: Claim) bool {
        return a.y > b.y;
    }
};

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    var claims = std.ArrayList(Claim){};
    claims.ensureTotalCapacity(allocator, 1500) catch unreachable;
    
    var nums: [5]u16 = undefined;
    var n: u16 = 0;
    var have: u1 = 0;
    var idx: usize = 0;
    
    for (input) |c| {
        const digit = c -% '0';
        if (digit < 10) {
            n = 10 * n + digit;
            have = 1;
        } else if (have != 0) {
            nums[idx] = n;
            idx += 1;
            if (idx == 5) {
                const x = nums[1];
                const w = nums[3];
                const shift: u6 = @intCast(x % 64);
                const mask: u64 = (@as(u64, 1) << @intCast(w)) - 1;
                
                claims.appendAssumeCapacity(.{
                    .id = nums[0],
                    .y = nums[2],
                    .h = nums[4],
                    .idx = @intCast(x / 64),
                    .mask0 = mask << shift,
                    .mask1 = if (shift != 0) (mask >> @as(u6, @truncate(64 - @as(u32, shift)))) else 0,
                    .part2 = true,
                });
                idx = 0;
            }
            n = 0;
            have = 0;
        }
    }
    
    std.mem.sort(Claim, claims.items, {}, Claim.lessThan);
    
    var part1: u32 = 0;
    var part2: u32 = 0;
    
    var row = [_]u64{0} ** 17;
    var collide = [_]u64{0} ** 17;
    
    while (claims.items.len > 0) {
        @memset(&row, 0);
        @memset(&collide, 0);
        
        const y = claims.items[claims.items.len - 1].y;
        
        var i = claims.items.len;
        while (i > 0 and claims.items[i - 1].y == y) {
            i -= 1;
            const claim = &claims.items[i];
            const idx0: usize = claim.idx;
            const idx1: usize = idx0 + 1;
            
            collide[idx0] |= row[idx0] & claim.mask0;
            row[idx0] |= claim.mask0;
            collide[idx1] |= row[idx1] & claim.mask1;
            row[idx1] |= claim.mask1;
        }
        
        var j = claims.items.len;
        while (j > 0 and claims.items[j - 1].y == y) {
            j -= 1;
            var claim = &claims.items[j];
            
            if (claim.part2) {
                const idx0: usize = claim.idx;
                const idx1: usize = idx0 + 1;
                if ((collide[idx0] & claim.mask0) != 0 or (collide[idx1] & claim.mask1) != 0) {
                    claim.part2 = false;
                }
            }
            
            claim.y += 1;
            claim.h -= 1;
            
            if (claim.h == 0) {
                if (claim.part2) {
                    part2 = claim.id;
                }
                _ = claims.swapRemove(j);
            }
        }
        
        for (collide) |c| {
            part1 += @popCount(c);
        }
    }
    
    return Result{ .p1 = part1, .p2 = part2 };
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
