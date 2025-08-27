const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const posix = std.poxix;

pub const ConfigValue = union(enum) {
    bool: bool,
    f32: f32,
    f64: f64,
    i128: i128,
    i16: i16,
    i32: i32,
    i64: i64,
    str: []const u8,
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
    config_options: std.array_list.Managed(ConfigOption),
    config: std.StringHashMap(ConfigValue),
    defaults: std.StringHashMap(ConfigValue),

    pub fn init(allocator: std.mem.Allocator, options: GnollOptions) Self {
        return Self{
            .allocator = allocator,
            .options = options,
            .config_options = std.array_list.Managed(ConfigOption).init(allocator),
            .config = std.StringHashMap(ConfigValue).init(allocator),
            .defaults = std.StringHashMap(ConfigValue).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.config_options.deinit();

        var config_iter = self.config.valueIterator();
        while (config_iter.next()) |entry| {
            const value = entry.*;

            switch (value) {
                .str => |s| self.allocator.free(s),
                else => {},
            }
        }
        self.config.deinit();

        var defaults_iter = self.defaults.valueIterator();
        while (defaults_iter.next()) |entry| {
            const value = entry.*;

            switch (value) {
                .str => |s| self.allocator.free(s),
                else => {},
            }
        }
        self.defaults.deinit();
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

        try self.config_options.append(option);
    }

    pub fn set(self: *Self, comptime T: type, key: []const u8, value: T) !void {
        const val_to_store: ConfigValue = switch (T) {
            bool => .{ .bool = value },
            []const u8 => blk: {
                const duped = try self.allocator.dupe(u8, value);
                break :blk .{ .str = duped };
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

        std.debug.print("current config count {}, capacity: {}\n", .{
            self.config.count(),
            self.config.capacity(),
        });
        try self.config.put(key, val_to_store);
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
                break :blk .{ .str = duped };
            },
            else => @compileError("Unsupported type in set()"),
        };

        try self.defaults.put(key, val_to_store);
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
                .str => |v| if (T == []const u8) v else null,
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
                .str => |v| if (T == []const u8) v else null,
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
            std.debug.print("File '{s}' does not exist\n", .{path});
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

        std.debug.print("checking path {s}\n", .{config_option.path});
        _ = std.fs.cwd().statFile(config_option.path) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("File '{s}' does not exist\n", .{config_option.path});
                return false;
            },
            else => {
                std.debug.print("File '{s}' could not be checked. {any}\n", .{
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
            std.debug.print("File '{s}' does not exist\n", .{config_option.path});
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

    try gnoll.set([]const u8, "str", "hello there");
    const str_val = gnoll.getAs([]const u8, "str").?;
    try testing.expect(std.mem.eql(u8, "hello there", str_val));

    try gnoll.setDefault(u32, "default", 54321);
    const default_val = gnoll.getAs(u32, "default").?;
    try testing.expectEqual(54321, default_val);

    try gnoll.setDefault(bool, "default_overridden", false);
    try gnoll.set(bool, "default_overridden", true);
    const default_val_overridden_val = gnoll.getAs(bool, "default_overridden").?;
    try testing.expectEqual(true, default_val_overridden_val);
}

test "casting" {
    const allocator = testing.allocator;

    const types = [_]type{
        bool,
        []const u8,
        f32,
        f64,
        i128,
        i16,
        i32,
        i64,
        u128,
        u16,
        u32,
        u64,
        u8,
    };

    var gnoll = Gnoll.init(allocator, .{});
    defer gnoll.deinit();

    var tmp_key_buffer: [32]u8 = undefined;

    inline for (0..types.len) |i| {
        const T = types[i];
        const key = try std.fmt.bufPrint(&tmp_key_buffer, "key_{}", .{i});

        switch (T) {
            u8, i16, u16, i32, u32, i64, u64, i128, u128 => {
                std.debug.print("key {s} T: {any}\n", .{ key, T });
                try gnoll.set(T, key, 1);

                const v = gnoll.getAs(T, key).?;
                std.debug.print("value {} T: {any}\n", .{ v, T });

                try testing.expectEqual(1, v);
            },
            f32, f64 => {
                std.debug.print("key {s} T: {any}\n", .{ key, T });
                try gnoll.set(T, key, 1.0);
                const v = gnoll.getAs(T, key).?;

                try testing.expectEqual(1.0, v);
            },
            bool => {
                std.debug.print("key {s} T: {any}\n", .{ key, T });
                try gnoll.set(T, key, true);
                const v = gnoll.getAs(T, key).?;

                try testing.expectEqual(true, v);
            },
            []const u8 => {
                std.debug.print("key {s} T: {any}\n", .{ key, T });
                try gnoll.set(T, key, "hello there");
                const v = gnoll.getAs(T, key).?;

                try testing.expect(std.mem.eql(u8, "hello there", v));
            },
            else => unreachable,
        }
    }
}
