const std = @import("std");

const Result = struct {
    p1: u64,
    p2: u64,
};

const Packet = union(enum) {
    Literal: struct { version: u64, type_id: u64, value: u64 },
    Operator: struct { version: u64, type_id: u64, packets: []Packet },
};

const BitStream = struct {
    available: u64,
    bits: u64,
    read: u64,
    index: usize,
    input: []const u8,

    fn init(input: []const u8) BitStream {
        return .{ .available = 0, .bits = 0, .read = 0, .index = 0, .input = input };
    }

    fn hexToBinary(self: *BitStream) u64 {
        const hex = self.input[self.index];
        self.index += 1;
        if (hex >= '0' and hex <= '9') return @as(u64, hex - '0');
        if (hex >= 'A' and hex <= 'F') return @as(u64, hex - 'A' + 10);
        return @as(u64, hex - 'a' + 10);
    }

    fn next(self: *BitStream, amount: u64) u64 {
        while (self.available < amount) {
            self.available += 4;
            self.bits = (self.bits << 4) | self.hexToBinary();
        }
        self.available -= amount;
        self.read += amount;
        const mask = (@as(u64, 1) << @as(u6, @intCast(amount))) - 1;
        return (self.bits >> @as(u6, @intCast(self.available))) & mask;
    }
};

fn parsePacket(stream: *BitStream, allocator: std.mem.Allocator) Packet {
    const version = stream.next(3);
    const type_id = stream.next(3);
    if (type_id == 4) {
        var value: u64 = 0;
        var more = true;
        while (more) {
            more = stream.next(1) == 1;
            value = (value << 4) | stream.next(4);
        }
        return .{ .Literal = .{ .version = version, .type_id = type_id, .value = value } };
    }

    var packets = std.ArrayListUnmanaged(Packet){};
    if (stream.next(1) == 0) {
        const target = stream.next(15) + stream.read;
        while (stream.read < target) {
            packets.append(allocator, parsePacket(stream, allocator)) catch unreachable;
        }
    } else {
        const count = stream.next(11);
        var i: u64 = 0;
        while (i < count) : (i += 1) {
            packets.append(allocator, parsePacket(stream, allocator)) catch unreachable;
        }
    }
    const slice = packets.toOwnedSlice(allocator) catch unreachable;
    return .{ .Operator = .{ .version = version, .type_id = type_id, .packets = slice } };
}

fn sumVersions(packet: Packet) u64 {
    return switch (packet) {
        .Literal => |p| p.version,
        .Operator => |p| blk: {
            var total = p.version;
            for (p.packets) |child| total += sumVersions(child);
            break :blk total;
        },
    };
}

fn eval(packet: Packet) u64 {
    return switch (packet) {
        .Literal => |p| p.value,
        .Operator => |p| blk: {
            switch (p.type_id) {
                0 => {
                    var total: u64 = 0;
                    for (p.packets) |child| total += eval(child);
                    break :blk total;
                },
                1 => {
                    var total: u64 = 1;
                    for (p.packets) |child| total *= eval(child);
                    break :blk total;
                },
                2 => {
                    var min: u64 = std.math.maxInt(u64);
                    for (p.packets) |child| {
                        const v = eval(child);
                        if (v < min) min = v;
                    }
                    break :blk min;
                },
                3 => {
                    var max: u64 = 0;
                    for (p.packets) |child| {
                        const v = eval(child);
                        if (v > max) max = v;
                    }
                    break :blk max;
                },
                5 => break :blk @as(u64, @intFromBool(eval(p.packets[0]) > eval(p.packets[1]))),
                6 => break :blk @as(u64, @intFromBool(eval(p.packets[0]) < eval(p.packets[1]))),
                7 => break :blk @as(u64, @intFromBool(eval(p.packets[0]) == eval(p.packets[1]))),
                else => break :blk 0,
            }
        },
    };
}

fn solve(input: []const u8) Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var stream = BitStream.init(std.mem.trim(u8, input, "\r\n"));
    const packet = parsePacket(&stream, allocator);
    return .{ .p1 = sumVersions(packet), .p2 = eval(packet) };
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
