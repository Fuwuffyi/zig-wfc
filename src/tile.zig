const std = @import("std");
const Color = @import("color.zig").Color;

pub const Direction = enum(u2) { up, down, left, right };

pub const Tile = struct {
    colors: []const []const Color,
    freq: u32,
    adjacencies: [4]std.DynamicBitSet, // Indexed using Direction

    pub fn init(colors: []const []const Color, freq: u32) @This() {
        return .{
            .colors = colors,
            .freq = freq,
            .adjacencies = .{
                undefined,
                undefined,
                undefined,
                undefined,
            },
        };
    }

    pub fn deinit(self: *@This(), allocator: *const std.mem.Allocator) void {
        defer allocator.free(self.colors);
        for (self.colors) |row| {
            allocator.free(row);
        }
        for (&self.adjacencies) |*adj| {
            adj.deinit();
        }
    }

    pub fn eql(a: *const @This(), b: []const []const Color) bool {
        if (a.colors.len != b.len) return false;
        for (0..a.colors.len) |i| {
            if (!std.mem.eql(Color, a.colors[i], b[i])) return false;
        }
        return true;
    }

    pub fn get_color_at(self: *const @This(), x: usize, y: usize) *const Color {
        if (y < 0 or y > self.colors.len) unreachable;
        if (x < 0 or x > self.colors[0].len) unreachable;
        return &self.colors[y][x];
    }

    pub fn calculate_adjacencies(self: *@This(), allocator: *const std.mem.Allocator, tile_size: u8, tileset: []const Tile) !void {
        // Clear adjacencies
        for (&self.adjacencies) |*adj| {
            adj.* = try std.DynamicBitSet.initEmpty(allocator.*, tileset.len);
        }
        // Helper variables
        const edge_width: u8 = (tile_size + 1) / 2;
        // Loop over all tiles
        for (tileset, 0..) |*other_tile, other_idx| {
            // Skip self
            if (self.eql(other_tile.colors)) continue;
            // Loop over directions
            for (std.enums.values(Direction)) |dir| {
                const match: bool = switch (dir) {
                    Direction.up => blk: {
                        for (0..edge_width) |y| {
                            for (0..self.colors[0].len) |x| {
                                if (!self.colors[y][x].eql(&other_tile.colors[y + edge_width - 1][x])) break :blk false;
                            }
                        }
                        break :blk true;
                    },
                    Direction.down => blk: {
                        for (0..edge_width) |y| {
                            for (0..self.colors[0].len) |x| {
                                if (!self.colors[y + edge_width - 1][x].eql(&other_tile.colors[y][x])) break :blk false;
                            }
                        }
                        break :blk true;
                    },
                    Direction.left => blk: {
                        for (0..self.colors.len) |y| {
                            for (0..edge_width) |x| {
                                if (!self.colors[y][x].eql(&other_tile.colors[y][x + edge_width - 1])) break :blk false;
                            }
                        }
                        break :blk true;
                    },
                    Direction.right => blk: {
                        for (0..self.colors.len) |y| {
                            for (0..edge_width) |x| {
                                if (!self.colors[y][x + edge_width - 1].eql(&other_tile.colors[y][x])) break :blk false;
                            }
                        }
                        break :blk true;
                    },
                };
                // If we have a match, add the adjacency
                if (match) {
                    self.adjacencies[@intFromEnum(dir)].set(@intCast(other_idx));
                }
            }
        }
    }
};
