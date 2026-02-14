const std = @import("std");
const os = std.os;
const linux = std.os.linux;
const fs = std.fs;
const path = fs.path;
const Io = std.Io;

const FICLONE = 0x40049409;

fn cloneFile(src_file: Io.File, dest_file: Io.File, total_size: u64) !void {
    const reflink = linux.ioctl(dest_file.handle, FICLONE, @intCast(src_file.handle));
    const reflink_errno = linux.errno(reflink);
    if (reflink_errno == .SUCCESS) {
        return;
    }

    var offset: u64 = 0;

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

    return error.FileCopyFailed;
}

fn cloneDir(
    alloc: std.mem.Allocator,
    io: Io,
    cwd: Io.Dir,
    stat: Io.Dir.Stat,
    src_path: []const u8,
    dest_path: []const u8,
) !void {
    const src_dir = try cwd.openDir(io, src_path, .{ .iterate = true });
    defer src_dir.close(io);

    const dest_dir = try cwd.createDirPathOpen(io, dest_path, .{ .permissions = stat.permissions });
    defer dest_dir.close(io);

    var walker = try src_dir.walk(alloc);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        switch (entry.kind) {
            .file => {
                const src_file = try entry.dir.openFile(io, entry.basename, .{});
                defer src_file.close(io);

                const file_stat = try src_file.stat(io);

                const dest_file = try dest_dir.createFile(io, entry.path, .{ .permissions = file_stat.permissions });
                defer dest_file.close(io);

                cloneFile(src_file, dest_file, file_stat.size) catch {
                    try cwd.copyFile(src_path, cwd, entry.path, io, .{ .permissions = file_stat.permissions });
                };
            },
            .directory => {
                try dest_dir.createDirPath(io, entry.path);
            },
            else => {},
        }
    }
}

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);

    if (args.len != 3) {
        std.debug.print("Usage: {s} <src> <dest>\n", .{args[0]});
        return error.InvalidArgs;
    }

    const io = init.io;
    const src_path = args[1];
    const dest_path = args[2];

    const cwd = Io.Dir.cwd();

    // manejo de directorios
    const src_stat = try cwd.statFile(io, src_path, .{});

    switch (src_stat.kind) {
        .file => {
            const src_file = try cwd.openFile(io, src_path, .{});
            defer src_file.close(io);

            const dest_file = try cwd.createFile(io, dest_path, .{ .permissions = src_stat.permissions });
            defer dest_file.close(io);

            cloneFile(src_file, dest_file, src_stat.size) catch {
                try cwd.copyFile(src_path, cwd, dest_path, io, .{ .permissions = src_stat.permissions });
            };
        },
        .directory => {
            try cloneDir(arena, io, cwd, src_stat, src_path, dest_path);
        },
        else => return error.UnexpectedEntryKind,
    }
}
