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
};

pub const Untyped = struct {};

pub const Gnoll = struct {
    const Self = @This();

    const Config = struct {
        config_info: ConfigInfo,
        parsed: *anyopaque,
        parsed_type: type,

        pub fn init(comptime parsed_type: type, parsed: *anyopaque, config_info: ConfigInfo) Config {
            return Config{
                .parsed_type = parsed_type,
                .parsed = parsed,
                .config_info = config_info,
            };
        }
    };

    // config: Config,

    pub fn init(comptime T: type, allocator: std.mem.Allocator, options: GnollOptions) !Self {
        _ = T;
        _ = allocator;
        _ = options;
        // try Gnoll.validateOptions(options);
        // const config_info = try Gnoll.getConfigInfo(options);

        // const config = try Gnoll.readConfig(T, allocator, config_info);
        // errdefer config.deinit();

        // const config = try options.parse(allocator, config_info);
        // errdefer allocator.destroy(config);

        return Self{
            // .allocator = allocator,
            // .gnoll_config = options,
            // .config_info = config_info,
            // .config = Config,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
        // self.config_candidates.deinit(self.allocator);
    }

    fn validateOptions(options: GnollOptions) !void {
        if (options.config_infos.len == 0) return error.MissingConfigInfo;

        var i: usize = 0;
        while (i < options.config_infos.len) : (i += 1) {
            if (i + 1 > options.config_infos.len) break; // we have exhausted the list, we are good
            const current = options.config_infos[i];

            for (i + 1..options.config_infos.len) |next_idx| {
                if (current.eql(options.config_infos[next_idx])) return error.DuplicateConfigInfo;
            }
        }
    }

    fn getConfigInfo(options: GnollOptions) !ConfigInfo {
        if (options.config_infos.len == 0) return error.MissingConfigCandidate;

        // for each candidate
        for (options.config_infos) |candidate| {
            // Check if the file exists
            log.debug("checking path {s}\n", .{candidate.filepath});
            _ = std.fs.cwd().statFile(candidate.filepath) catch |err| switch (err) {
                error.FileNotFound => {
                    log.err("File '{s}' does not exist\n", .{candidate.filepath});
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

    fn readConfig(comptime T: type, allocator: std.mem.Allocator, config_info: ConfigInfo) !Config {
        // figure out if the file exists or return an error
        const file = std.fs.cwd().openFile(config_info.filepath, .{}) catch |err| {
            log.err("File '{s}' does not exist\n", .{config_info.filepath});
            return err;
        };
        defer file.close();

        const stat = try file.stat();
        const file_size = stat.size;

        const buf = try allocator.alloc(u8, file_size);
        defer allocator.free(buf);

        const n = try file.readAll(buf);

        if (n != file_size) return error.UnexepectedFileReadError;

        // figure out how to parse this config
        // if this is a json config
        switch (config_info.format) {
            .json => {
                const parsed: json.Parsed(T) = try json.parseFromSlice(T, allocator, buf, .{});
                errdefer parsed.deinit();

                return Config.init(json.Parsed(T), parsed, parsed.value);

                // return Config{
                //     .parsed = parsed,
                //     .value = parsed.value,
                // };
            },
            else => unreachable,
        }

        // return Config{};
    }
};
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

    var gnoll = try Gnoll.init(MyConfigFileType, allocator, gnoll_options);
    defer gnoll.deinit(allocator);

    // try testing.expectEqual(0, gnoll.config_candidates.items.len);

    // try gnoll.addConfigInfo(allocator, "./test_data/config_0.json", .json);
    // try gnoll.addConfigInfo(allocator, "./test_data/config_1.yaml", .yaml);

    // try testing.expectEqual(2, gnoll.config_candidates.items.len);

    // const config = try gnoll.readConfig();
    // defer config.deinit();

    // const config = try gnoll.readConfig(MyConfigFileType, allocator);

    // const config = try gnoll.readConfig(MyConfigFileType, allocator);
    // log.err("read config {any}", .{config});

    // const config = try gnoll.getConfig();
    // log.info("config {any}", .{config});
    // const my_bool = config.get(bool, "my.bool", false);
    // cosnt my_bytes = config.get([]const u8, "my.string", "hello");
}
