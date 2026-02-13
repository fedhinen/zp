const std = @import("std");
const os = std.os;
const linux = std.os.linux;
const fs = std.fs;

const FICLONE: u64 = 0x40049409;

const Io = std.Io;

const zp = @import("zp");

pub fn main(init: std.process.Init) !void {
    // Prints to stderr, unbuffered, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    const io = init.io;
    const src_path = args[1];
    const dest_path = args[2];

    const cwd = Io.Dir.cwd();
    const src_file = try cwd.openFile(io, src_path, .{});
    defer src_file.close(io);

    const dest_file = try cwd.openFile(io, dest_path, .{});
    defer dest_file.close(io);

    const reflink = linux.ioctl(dest_file.handle, FICLONE, @intCast(src_file.handle));
    const reflink_errno = linux.errno(reflink);
    if (reflink_errno != .SUCCESS) {
        std.debug.print("Failed to reflink:\n", .{});
    } else {
        std.debug.print("Reflinked successfully!\n", .{});
        return;
    }

    var offset: u64 = 0;
    const stat = try src_file.stat(io);
    const total_size = stat.size;

    while (offset < total_size) {
        const bytes_copied = linux.copy_file_range(src_file.handle, null, dest_file.handle, null, total_size - offset, 0);

        const copy_errno = linux.errno(bytes_copied);

        if (copy_errno != .SUCCESS) {
            std.debug.print("Failed to copy\n", .{});
            break;
        }

        offset += bytes_copied;
        if (bytes_copied == 0) {
            break;
        }
    }

    if (offset == total_size) {
        std.debug.print("Copied successfully!\n", .{});
        return;
    } else {
        std.debug.print("Failed to copy the entire file.\n", .{});
    }

    try cwd.copyFile(src_path, cwd, dest_path, io, .{});

    // In order to do I/O operations need an `Io` instance.

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try stdout_writer.flush(); // Don't forget to flush!
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
