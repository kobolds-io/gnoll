const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const posix = std.poxix;
const log = std.log.scoped(.Gnoll);
const json = std.json;

const ConfigFormat = enum {
    json,
    yaml,
};

const ConfigInfo = struct {
    filepath: []const u8,
    format: ConfigFormat,

    pub fn eql(self: ConfigInfo, other: ConfigInfo) bool {
        if (self.format != other.format) return false;
        if (!std.mem.eql(u8, self.filepath, other.filepath)) return false;

        return true;
    }
};

pub const GnollOptions = struct {
    config_infos: []const ConfigInfo = &.{},
    ignore_unknown_fields: bool = false,

    pub fn validate(self: GnollOptions) !void {
        if (self.config_infos.len == 0) return error.MissingConfigInfo;

        var i: usize = 0;
        while (i < self.config_infos.len) : (i += 1) {
            if (i + 1 > self.config_infos.len) break; // we have exhausted the list, we are good
            const current = self.config_infos[i];

            for (i + 1..self.config_infos.len) |next_idx| {
                if (current.eql(self.config_infos[next_idx])) return error.DuplicateConfigInfo;
            }
        }
    }

    pub fn getConfigInfo(self: GnollOptions) !ConfigInfo {
        if (self.config_infos.len == 0) return error.MissingConfigCandidate;

        // for each candidate
        for (self.config_infos) |candidate| {
            // Check if the file exists
            log.debug("checking path {s}\n", .{candidate.filepath});
            _ = std.fs.cwd().statFile(candidate.filepath) catch |err| switch (err) {
                error.FileNotFound => {
                    continue;
                },
                else => {
                    log.err("File '{s}' could not be checked. {any}\n", .{
                        candidate.filepath,
                        err,
                    });
                    continue;
                },
            };

            return candidate;
        }

        return error.NoEligibleConfigInfoFound;
    }
};

pub const Untyped = struct {};

pub fn Gnoll(comptime T: type) type {
    return struct {
        const Self = @This();

        config_info: ConfigInfo,
        config: T,
        parsed_ptr: *anyopaque,
        source_buf: []u8,

        pub fn init(allocator: std.mem.Allocator, options: GnollOptions) !Self {
            try options.validate();
            const config_info = try options.getConfigInfo();

            // read the file
            // figure out if the file exists or return an error
            const file = try std.fs.cwd().openFile(config_info.filepath, .{});
            defer file.close();

            const stat = try file.stat();
            const file_size = stat.size;

            const buf = try allocator.alloc(u8, file_size);
            errdefer allocator.free(buf);

            const n = try file.readAll(buf);

            if (n != file_size) return error.UnexepectedFileReadError;

            switch (config_info.format) {
                .json => {
                    const parsed: json.Parsed(T) = try json.parseFromSlice(
                        T,
                        allocator,
                        buf,
                        .{ .ignore_unknown_fields = options.ignore_unknown_fields },
                    );
                    errdefer parsed.deinit();

                    const parsed_ptr = try allocator.create(json.Parsed(T));
                    errdefer allocator.destroy(parsed_ptr);

                    parsed_ptr.* = parsed;

                    return Self{
                        .config_info = config_info,
                        .parsed_ptr = parsed_ptr,
                        .config = parsed.value,
                        .source_buf = buf,
                    };
                },
                else => unreachable,
            }
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            switch (self.config_info.format) {
                .json => {
                    const parsed_ptr: *json.Parsed(T) = @ptrCast(@alignCast(self.parsed_ptr));
                    parsed_ptr.deinit();

                    allocator.free(self.source_buf);
                    allocator.destroy(parsed_ptr);
                },
                else => unreachable,
            }
        }
    };
}

test "basic workflow" {
    const allocator = testing.allocator;

    const MyConfigFileType = struct {
        key_0: u32,
        key_1: []const u8,
        key_2: struct {
            key_0: []f32,
        },
    };

    const gnoll_options = GnollOptions{
        .ignore_unknown_fields = false,
        .config_infos = &.{
            ConfigInfo{
                .filepath = "./test_data/config_0.json",
                .format = .json,
            },
            ConfigInfo{
                .filepath = "./test_data/config_1.yaml",
                .format = .yaml,
            },
        },
    };

    var gnoll = try Gnoll(MyConfigFileType).init(allocator, gnoll_options);
    defer gnoll.deinit(allocator);

    try testing.expectEqual(54321, gnoll.config.key_0);
    try testing.expect(std.mem.eql(u8, "some bytes value", gnoll.config.key_1));
    try testing.expect(std.mem.eql(f32, &.{ 1.23, 3.14 }, gnoll.config.key_2.key_0));
}

test "error on duplicate config" {
    const allocator = testing.allocator;

    const MyConfigFileType = struct {
        key_0: u32,
        key_1: []const u8,
        key_2: struct {
            key_0: []f32,
        },
    };

    const gnoll_options = GnollOptions{
        .ignore_unknown_fields = false,
        .config_infos = &.{
            ConfigInfo{
                .filepath = "./test_data/config_0.json",
                .format = .json,
            },
            ConfigInfo{
                .filepath = "./test_data/config_0.json",
                .format = .json,
            },
        },
    };

    try testing.expectError(error.DuplicateConfigInfo, Gnoll(MyConfigFileType).init(allocator, gnoll_options));
}

test "error no config info" {
    const allocator = testing.allocator;

    const MyConfigFileType = struct {
        key_0: u32,
        key_1: []const u8,
        key_2: struct {
            key_0: []f32,
        },
    };

    const gnoll_options = GnollOptions{
        .ignore_unknown_fields = false,
        .config_infos = &.{},
    };

    try testing.expectError(error.MissingConfigInfo, Gnoll(MyConfigFileType).init(allocator, gnoll_options));
}

test "file not found" {
    const allocator = testing.allocator;

    const MyConfigFileType = struct {
        key_0: u32,
        key_1: []const u8,
        key_2: struct {
            key_0: []f32,
        },
    };

    const gnoll_options = GnollOptions{
        .ignore_unknown_fields = false,
        .config_infos = &.{
            ConfigInfo{
                .filepath = "/tmp/bullshitfile",
                .format = .json,
            },
        },
    };

    try testing.expectError(error.NoEligibleConfigInfoFound, Gnoll(MyConfigFileType).init(allocator, gnoll_options));
}

test "error on invalid parsing of file" {
    const allocator = testing.allocator;

    const MyConfigFileType = struct {
        key_0: u32,
        key_1: []const u8,
        key_2: struct {
            key_0: []f32,
        },
    };

    // Using a yaml file that is not json
    const gnoll_options = GnollOptions{
        .ignore_unknown_fields = false,
        .config_infos = &.{
            ConfigInfo{
                .filepath = "./test_data/config_1.yaml",
                .format = .json,
            },
        },
    };

    try testing.expectError(error.SyntaxError, Gnoll(MyConfigFileType).init(allocator, gnoll_options));
}
