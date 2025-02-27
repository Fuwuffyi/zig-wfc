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
            if (a.colors[i].len != b[i].len) return false;
            for (0..a.colors[i].len) |j| {
                if (!a.get_color_at(j, i).eql(&b[j][i])) return false;
            }
        }
        return true;
    }

    pub fn get_color_at(self: *const @This(), x: usize, y: usize) *const Color {
        if (y >= self.colors.len) unreachable;
        const row = self.colors[y];
        if (x >= row.len) unreachable;
        return &row[x];
    }

    pub fn calculate_adjacencies(self: *@This(), allocator: *const std.mem.Allocator, tile_size: u8, tileset: []const Tile) !void {
        // Clear adjacencies
        for (&self.adjacencies) |*adj| {
            adj.* = try std.DynamicBitSet.initEmpty(allocator.*, tileset.len);
        }
        // Helper variables
        const edge_width: u8 = (tile_size + 1) / 2;
        const right_edge_start: u8 = tile_size - edge_width;
        // Loop over all tiles
        for (tileset, 0..) |*other_tile, other_idx| {
            // Skip self
            if (self.eql(other_tile.colors)) continue;
            // Loop over directions
            for (std.enums.values(Direction)) |dir| {
                const match: bool = switch (dir) {
                    Direction.up => blk: {
                        for (0..edge_width) |y| {
                            if (!std.mem.eql(Color, self.colors[y], other_tile.colors[y + edge_width - 1])) break :blk false;
                        }
                        break :blk true;
                    },
                    Direction.down => blk: {
                        for (0..edge_width) |y| {
                            if (!std.mem.eql(Color, self.colors[y + edge_width - 1], other_tile.colors[y])) break :blk false;
                        }
                        break :blk true;
                    },
                    Direction.left => blk: {
                        for (0..self.colors.len) |y| {
                            const self_edge = self.colors[y][0..edge_width];
                            const other_edge = other_tile.colors[y][right_edge_start..];
                            if (!std.mem.eql(Color, self_edge, other_edge)) break :blk false;
                        }
                        break :blk true;
                    },
                    Direction.right => blk: {
                        for (0..self.colors.len) |y| {
                            const self_edge = self.colors[y][right_edge_start..];
                            const other_edge = other_tile.colors[y][0..edge_width];
                            if (!std.mem.eql(Color, self_edge, other_edge))
                                break :blk false;
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
