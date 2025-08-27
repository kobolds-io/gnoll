const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const posix = std.poxix;
const log = std.log.scoped(.Gnoll);

pub const ConfigValue = union(enum) {
    bool: bool,
    f32: f32,
    f64: f64,
    i128: i128,
    i16: i16,
    i32: i32,
    i64: i64,
    bytes: []const u8,
    u128: u128,
    u16: u16,
    u32: u32,
    u64: u64,
    u8: u8,
};

pub const Gnoll = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    options: GnollOptions,
    config_options: std.ArrayList(ConfigOption),
    config: std.StringHashMapUnmanaged(ConfigValue),
    defaults: std.StringHashMapUnmanaged(ConfigValue),

    pub fn init(allocator: std.mem.Allocator, options: GnollOptions) Self {
        return Self{
            .allocator = allocator,
            .options = options,
            .config_options = .empty,
            .config = .empty,
            .defaults = .empty,
        };
    }

    pub fn deinit(self: *Self) void {
        self.config_options.deinit(self.allocator);

        var config_iter = self.config.valueIterator();
        while (config_iter.next()) |entry| {
            const value = entry.*;

            switch (value) {
                .bytes => |s| self.allocator.free(s),
                else => {},
            }
        }
        self.config.deinit(self.allocator);

        var defaults_iter = self.defaults.valueIterator();
        while (defaults_iter.next()) |entry| {
            const value = entry.*;

            switch (value) {
                .bytes => |s| self.allocator.free(s),
                else => {},
            }
        }
        self.defaults.deinit(self.allocator);
    }

    pub fn addConfigOption(self: *Self, filepath: []const u8, config_type: ConfigType) !void {
        if (filepath.len >= std.posix.PATH_MAX) return error.FilepathLenExceedsCapacity;

        const option = ConfigOption{
            .path = filepath,
            .config_type = config_type,
        };

        for (self.config_options.items) |existing_option| {
            if (existing_option.eql(option)) return error.DuplicateConfigOption;
        }

        try self.config_options.append(self.allocator, option);
    }

    pub fn set(self: *Self, comptime T: type, key: []const u8, value: T) !void {
        const val_to_store: ConfigValue = switch (T) {
            bool => .{ .bool = value },
            []const u8 => blk: {
                const duped = try self.allocator.dupe(u8, value);
                break :blk .{ .bytes = duped };
            },
            f32 => .{ .f32 = value },
            f64 => .{ .f64 = value },
            i128 => .{ .i128 = value },
            i16 => .{ .i16 = value },
            i32 => .{ .i32 = value },
            i64 => .{ .i64 = value },
            u128 => .{ .u128 = value },
            u16 => .{ .u16 = value },
            u32 => .{ .u32 = value },
            u64 => .{ .u64 = value },
            u8 => .{ .u8 = value },
            else => @compileError("Unsupported type in set()"),
        };

        log.debug("current config count {d}, capacity: {d}\n", .{
            self.config.count(),
            self.config.capacity(),
        });
        try self.config.put(self.allocator, key, val_to_store);
    }

    pub fn setDefault(self: *Self, comptime T: type, key: []const u8, value: T) !void {
        const val_to_store: ConfigValue = switch (T) {
            bool => .{ .bool = value },
            f32 => .{ .f32 = value },
            f64 => .{ .f64 = value },
            i128 => .{ .i128 = value },
            i16 => .{ .i16 = value },
            i32 => .{ .i32 = value },
            i64 => .{ .i64 = value },
            u128 => .{ .u128 = value },
            u16 => .{ .u16 = value },
            u32 => .{ .u32 = value },
            u64 => .{ .u64 = value },
            u8 => .{ .u8 = value },
            []const u8 => blk: {
                const duped = try self.allocator.dupe(u8, value);
                break :blk .{ .bytes = duped };
            },
            else => @compileError("Unsupported type in set()"),
        };

        try self.defaults.put(self.allocator, key, val_to_store);
    }

    pub fn getAs(self: *Self, comptime T: type, key: []const u8) ?T {
        if (self.config.get(key)) |val| {
            return switch (val) {
                .bool => |v| if (T == bool) v else null,
                .f32 => |v| if (T == f32) v else null,
                .f64 => |v| if (T == f64) v else null,
                .i128 => |v| if (T == i128) v else null,
                .i16 => |v| if (T == i16) v else null,
                .i32 => |v| if (T == i32) v else null,
                .i64 => |v| if (T == i64) v else null,
                .bytes => |v| if (T == []const u8) v else null,
                .u128 => |v| if (T == u128) v else null,
                .u16 => |v| if (T == u16) v else null,
                .u32 => |v| if (T == u32) v else null,
                .u64 => |v| if (T == u64) v else null,
                .u8 => |v| if (T == u8) v else null,
            };
        }
        return self.getDefaultAs(T, key);
    }

    fn getDefaultAs(self: *Self, comptime T: type, key: []const u8) ?T {
        if (self.defaults.get(key)) |val| {
            return switch (val) {
                .bool => |v| if (T == bool) v else null,
                .f32 => |v| if (T == f32) v else null,
                .f64 => |v| if (T == f64) v else null,
                .i128 => |v| if (T == i128) v else null,
                .i16 => |v| if (T == i16) v else null,
                .i32 => |v| if (T == i32) v else null,
                .i64 => |v| if (T == i64) v else null,
                .bytes => |v| if (T == []const u8) v else null,
                .u128 => |v| if (T == u128) v else null,
                .u16 => |v| if (T == u16) v else null,
                .u32 => |v| if (T == u32) v else null,
                .u64 => |v| if (T == u64) v else null,
                .u8 => |v| if (T == u8) v else null,
            };
        }
        return null;
    }

    fn readFile(self: *Self, path: []const u8) !void {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            log.err("File '{s}' does not exist\n", .{path});
            return err;
        };
        defer file.close();

        const stat = try file.stat();
        const file_size = stat.size;

        const buf = try self.allocator.alloc(u8, file_size);
        errdefer self.allocator.free(buf);

        const n = try file.readAll(buf);

        if (n != file_size) return error.UnexepectedFileReadError;

        self.config_buffer = buf;
    }

    fn checkFileExists(self: *Self, config_option: ConfigOption) bool {
        _ = self;

        log.debug("checking path {s}\n", .{config_option.path});
        _ = std.fs.cwd().statFile(config_option.path) catch |err| switch (err) {
            error.FileNotFound => {
                log.err("File '{s}' does not exist\n", .{config_option.path});
                return false;
            },
            else => {
                log.err("File '{s}' could not be checked. {any}\n", .{
                    config_option.path,
                    err,
                });
                return false;
            },
        };

        return true;
    }

    fn getConfigFile(self: *Self) !void {
        const config_option = try self.findValidConfigOption();

        const file = std.fs.cwd().openFile(config_option.path, .{}) catch |err| {
            log.err("File '{s}' does not exist\n", .{config_option.path});
            return err;
        };
        defer file.close();

        const stat = try file.stat();
        const file_size = stat.size;

        const config_buf = try self.allocator.alloc(u8, file_size);
        errdefer self.allocator.free(config_buf);

        const n = try file.readAll(config_buf);

        if (n != file_size) return error.UnexepectedFileReadError;

        self.config = config_buf;
    }

    fn findValidConfigOption(self: *Self) !ConfigOption {
        for (self.config_options.items) |config_option| {
            if (self.checkFileExists(config_option)) return config_option;
        }

        return error.ConfigFileNotFound;
    }
};

pub const ConfigOption = struct {
    path: []const u8,
    config_type: ConfigType,

    pub fn eql(self: ConfigOption, other: ConfigOption) bool {
        if (self.config_type != other.config_type) return false;
        if (!std.mem.eql(u8, self.path, other.path)) return false;

        return true;
    }
};

pub const GnollOptions = struct {};

pub const ConfigType = enum {
    json,
};

test "basic init/deinit" {
    const allocator = testing.allocator;

    var gnoll = Gnoll.init(allocator, .{});
    defer gnoll.deinit();
}

test "read a config file" {
    const allocator = testing.allocator;

    var gnoll = Gnoll.init(allocator, .{});
    defer gnoll.deinit();

    try gnoll.addConfigOption("./test_data/config_0.json", .json);
    try gnoll.addConfigOption("./test_data/config_1.json", .json);

    try testing.expectError(error.DuplicateConfigOption, gnoll.addConfigOption(
        "./test_data/config_1.json",
        .json,
    ));

    try testing.expectEqual(2, gnoll.config_options.items.len);

    try gnoll.set(u8, "u8", 123);
    const u8_val = gnoll.getAs(u8, "u8").?;

    try testing.expectEqual(123, u8_val);

    try gnoll.set([]const u8, "bytes", "hello there");
    const bytes_val = gnoll.getAs([]const u8, "bytes").?;
    try testing.expect(std.mem.eql(u8, "hello there", bytes_val));

    try gnoll.setDefault(u32, "default", 54321);
    const default_val = gnoll.getAs(u32, "default").?;
    try testing.expectEqual(54321, default_val);

    try gnoll.setDefault(bool, "default_overridden", false);
    try gnoll.set(bool, "default_overridden", true);
    const default_val_overridden_val = gnoll.getAs(bool, "default_overridden").?;
    try testing.expectEqual(true, default_val_overridden_val);
}

test "read json config file" {
    const allocator = testing.allocator;

    var gnoll = Gnoll.init(allocator, .{});
    defer gnoll.deinit();

    // const config = try gnoll.getConfig();
    // const my_bool = config.get(bool, "my.bool", false);
    // cosnt my_bytes = config.get([]const u8, "my.string", "hello");

}
