// Host side of the Day 04 GPU search. Loads the NVIDIA driver at runtime and launches the
// PTX kernel from day04_gpu_kernel.zig, so no CUDA toolkit or nvcc is needed to build it.
const std = @import("std");

const ptx = @embedFile("day04_gpu_kernel.ptx");

const CUresult = c_int;
const CUdevice = c_int;
const CUcontext = ?*anyopaque;
const CUmodule = ?*anyopaque;
const CUfunction = ?*anyopaque;
const CUdeviceptr = u64;

const Driver = struct {
    init: *const fn (c_uint) callconv(.c) CUresult,
    deviceGet: *const fn (*CUdevice, c_int) callconv(.c) CUresult,
    ctxRetain: *const fn (*CUcontext, CUdevice) callconv(.c) CUresult,
    ctxSetCurrent: *const fn (CUcontext) callconv(.c) CUresult,
    moduleLoadData: *const fn (*CUmodule, *const anyopaque) callconv(.c) CUresult,
    moduleGetFunction: *const fn (*CUfunction, CUmodule, [*:0]const u8) callconv(.c) CUresult,
    memAlloc: *const fn (*CUdeviceptr, usize) callconv(.c) CUresult,
    memFree: *const fn (CUdeviceptr) callconv(.c) CUresult,
    memset32: *const fn (CUdeviceptr, u32, usize) callconv(.c) CUresult,
    memcpyDtoH: *const fn (*anyopaque, CUdeviceptr, usize) callconv(.c) CUresult,
    launch: *const fn (CUfunction, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, ?*anyopaque, [*]?*anyopaque, ?*anyopaque) callconv(.c) CUresult,
    sync: *const fn () callconv(.c) CUresult,
};

fn loadDriver(lib: *std.DynLib) !Driver {
    return .{
        .init = lib.lookup(*const fn (c_uint) callconv(.c) CUresult, "cuInit") orelse return error.MissingSymbol,
        .deviceGet = lib.lookup(*const fn (*CUdevice, c_int) callconv(.c) CUresult, "cuDeviceGet") orelse return error.MissingSymbol,
        .ctxRetain = lib.lookup(*const fn (*CUcontext, CUdevice) callconv(.c) CUresult, "cuDevicePrimaryCtxRetain") orelse return error.MissingSymbol,
        .ctxSetCurrent = lib.lookup(*const fn (CUcontext) callconv(.c) CUresult, "cuCtxSetCurrent") orelse return error.MissingSymbol,
        .moduleLoadData = lib.lookup(*const fn (*CUmodule, *const anyopaque) callconv(.c) CUresult, "cuModuleLoadData") orelse return error.MissingSymbol,
        .moduleGetFunction = lib.lookup(*const fn (*CUfunction, CUmodule, [*:0]const u8) callconv(.c) CUresult, "cuModuleGetFunction") orelse return error.MissingSymbol,
        .memAlloc = lib.lookup(*const fn (*CUdeviceptr, usize) callconv(.c) CUresult, "cuMemAlloc_v2") orelse return error.MissingSymbol,
        .memFree = lib.lookup(*const fn (CUdeviceptr) callconv(.c) CUresult, "cuMemFree_v2") orelse return error.MissingSymbol,
        .memset32 = lib.lookup(*const fn (CUdeviceptr, u32, usize) callconv(.c) CUresult, "cuMemsetD32_v2") orelse return error.MissingSymbol,
        .memcpyDtoH = lib.lookup(*const fn (*anyopaque, CUdeviceptr, usize) callconv(.c) CUresult, "cuMemcpyDtoH_v2") orelse return error.MissingSymbol,
        .launch = lib.lookup(*const fn (CUfunction, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, c_uint, ?*anyopaque, [*]?*anyopaque, ?*anyopaque) callconv(.c) CUresult, "cuLaunchKernel") orelse return error.MissingSymbol,
        .sync = lib.lookup(*const fn () callconv(.c) CUresult, "cuCtxSynchronize") orelse return error.MissingSymbol,
    };
}

const batch: u32 = 1 << 24;
const threads: c_uint = 256;

fn process(drv: *const Driver, fun: CUfunction, digits: u32, d_best1: CUdeviceptr, d_best2: CUdeviceptr) !void {
    var lo: u32 = 1;
    var i: u32 = 1;
    while (i < digits) : (i += 1) lo *= 10;
    const hi = lo * 10;

    var s = lo;
    while (s < hi) {
        const cnt = @min(hi - s, batch);
        var start = s;
        var count = cnt;
        var dig = digits;
        var b1 = d_best1;
        var b2 = d_best2;
        var params = [_]?*anyopaque{ &start, &count, &dig, &b1, &b2 };
        const blocks: c_uint = @intCast((cnt + threads - 1) / threads);
        if (drv.launch(fun, blocks, 1, 1, threads, 1, 1, 0, null, &params, null) != 0) return error.LaunchFailed;
        s += cnt;
    }
}

pub fn main() !void {
    var lib = try std.DynLib.open("nvcuda.dll");
    defer lib.close();
    const drv = try loadDriver(&lib);

    if (drv.init(0) != 0) return error.InitFailed;
    var dev: CUdevice = undefined;
    if (drv.deviceGet(&dev, 0) != 0) return error.NoDevice;
    var ctx: CUcontext = undefined;
    if (drv.ctxRetain(&ctx, dev) != 0) return error.ContextFailed;
    if (drv.ctxSetCurrent(ctx) != 0) return error.ContextFailed;

    var module: CUmodule = undefined;
    if (drv.moduleLoadData(&module, ptx.ptr) != 0) return error.ModuleFailed;
    var fun: CUfunction = undefined;
    if (drv.moduleGetFunction(&fun, module, "search") != 0) return error.ModuleFailed;

    var d_best1: CUdeviceptr = undefined;
    var d_best2: CUdeviceptr = undefined;
    _ = drv.memAlloc(&d_best1, 4);
    _ = drv.memAlloc(&d_best2, 4);
    _ = drv.memset32(d_best1, 0xFFFFFFFF, 1);
    _ = drv.memset32(d_best2, 0xFFFFFFFF, 1);

    var timer = try std.time.Timer.start();
    var digits: u32 = 1;
    while (digits <= 7) : (digits += 1) try process(&drv, fun, digits, d_best1, d_best2);
    if (drv.sync() != 0) return error.LaunchFailed;
    var p1: u32 = undefined;
    var p2: u32 = undefined;
    _ = drv.memcpyDtoH(&p1, d_best1, 4);
    _ = drv.memcpyDtoH(&p2, d_best2, 4);
    const us = @as(f64, @floatFromInt(timer.read())) / 1000.0;

    std.debug.print("Part 1: {}\nPart 2: {}\n", .{ p1, p2 });
    std.debug.print("Time: {d:.2} microseconds\n", .{us});
}
