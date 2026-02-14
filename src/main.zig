const std = @import("std");
const os = std.os;
const linux = std.os.linux;
const fs = std.fs;

const Io = std.Io;
const FICLONE = 0x40049409;
const zp = @import("zp");

pub fn main(init: std.process.Init) !void {

    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);
    if (args.len != 3) {
        std.debug.print("Usage: {s} <src> <dest>\n", .{args[0]});
        return error.InvalidArgs;
    }

    const io = init.io;
    const src_path = args[1];
    const dest_path = args[2];

    const cwd = Io.Dir.cwd();
    const src_file = try cwd.openFile(io, src_path, .{});
    defer src_file.close(io);

    const dest_file = try cwd.createFile(io, dest_path, .{});
    defer dest_file.close(io);

    const reflink = linux.ioctl(dest_file.handle, FICLONE, @intCast(src_file.handle));
    const reflink_errno = linux.errno(reflink);
    if (reflink_errno == .SUCCESS) {
        return;
    }

    var offset: u64 = 0;
    const stat = try src_file.stat(io);
    const total_size = stat.size;

    while (offset < total_size) {
        const bytes_copied = linux.copy_file_range(src_file.handle, null, dest_file.handle, null, total_size - offset, 0);

        const copy_errno = linux.errno(bytes_copied);

        if (copy_errno != .SUCCESS) {
            break;
        }

        offset += bytes_copied;
        if (bytes_copied == 0) {
            break;
        }
    }

    if (offset == total_size) {
        return;
    }

    try cwd.copyFile(src_path, cwd, dest_path, io, .{});
}
