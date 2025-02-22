const std = @import("std");
const Color = @import("color.zig").Color;

pub const Direction = enum(u2) { up, down, left, right };

pub const Tile = struct {
    colors: []const Color,
    freq: u32,
    adjacencies: [4]std.DynamicBitSet, // Indexed using Direction

    pub fn init(colors: []const Color, freq: u32) @This() {
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
        allocator.free(self.colors);
        for (&self.adjacencies) |*adj| {
            adj.deinit();
        }
    }

    pub fn eql(a: *const @This(), b: []const Color) bool {
        if (a.colors.len != b.len) return false;
        for (a.colors, b) |*color_a, *color_b| {
            if (!color_a.eql(color_b)) return false;
        }
        return true;
    }

    pub fn calculate_adjacencies(self: *@This(), allocator: *const std.mem.Allocator, tile_size: u8, tileset: []const Tile) !void {
        // Clear adjacencies
        for (&self.adjacencies) |*adj| {
            adj.* = try std.DynamicBitSet.initEmpty(allocator.*, tileset.len);
        }
        // Helper variables
        const edge_width: u8 = (tile_size + 1) / 2;
        const len: u32 = edge_width * tile_size;
        // Loop over all tiles
        for (tileset, 0..) |*other_tile, other_idx| {
            // Skip self
            if (self.eql(other_tile.colors)) continue;
            // Loop over directions
            const directions: [4]Direction = .{ Direction.up, Direction.down, Direction.left, Direction.right };
            for (directions) |dir| {
                // Current adjacency list
                const opposite_dir: Direction = switch (dir) {
                    .up => .down,
                    .down => .up,
                    .left => .right,
                    .right => .left,
                };
                var match: bool = true;
                var i: usize = 0;
                // Run over all the colors for the direction and opposite direction
                while (i < len) : (i += 1) {
                    const current_idx = blk: {
                        switch (dir) {
                            .up => {
                                const row = i / tile_size;
                                const col = i % tile_size;
                                break :blk row * tile_size + col;
                            },
                            .down => {
                                const start_row = tile_size - edge_width;
                                const row = start_row + (i / tile_size);
                                const col = i % tile_size;
                                break :blk row * tile_size + col;
                            },
                            .left => {
                                const col = i / tile_size;
                                const row = i % tile_size;
                                break :blk row * tile_size + col;
                            },
                            .right => {
                                const start_col = tile_size - edge_width;
                                const col = start_col + (i / tile_size);
                                const row = i % tile_size;
                                break :blk row * tile_size + col;
                            },
                        }
                    };
                    const other_idx_color = blk: {
                        switch (opposite_dir) {
                            .up => {
                                const row = i / tile_size;
                                const col = i % tile_size;
                                break :blk row * tile_size + col;
                            },
                            .down => {
                                const start_row = tile_size - edge_width;
                                const row = start_row + (i / tile_size);
                                const col = i % tile_size;
                                break :blk row * tile_size + col;
                            },
                            .left => {
                                const col = i / tile_size;
                                const row = i % tile_size;
                                break :blk row * tile_size + col;
                            },
                            .right => {
                                const start_col = tile_size - edge_width;
                                const col = start_col + (i / tile_size);
                                const row = i % tile_size;
                                break :blk row * tile_size + col;
                            },
                        }
                    };
                    // Check if we are out of bounds
                    if (current_idx >= self.colors.len or other_idx_color >= other_tile.colors.len) {
                        match = false;
                        break;
                    }
                    // Check if the colors match
                    if (!self.colors[current_idx].eql(&other_tile.colors[other_idx_color])) {
                        match = false;
                        break;
                    }
                }
                // If we have a match, add the adjacency
                if (match) {
                    self.adjacencies[@intFromEnum(dir)].set(@intCast(other_idx));
                }
            }
        }
    }
};
