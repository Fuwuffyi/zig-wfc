const std = @import("std");
const zigimg = @import("zigimg");

const Color = struct { r: u8, g: u8, b: u8 };

pub const Tile = struct {
    colors: []Color,
    freq: u32,

    pub fn generate_tiles(allocator: *const std.mem.Allocator, image_file: []const u8, tile_size: u8) ![]Tile {
        // Read image
        var image = try zigimg.Image.fromFilePath(allocator.*, image_file);
        defer image.deinit();
        // Create the tiles to return
        const tiles: []Tile = try allocator.alloc(Tile, image.width * image.height);
        errdefer allocator.free(tiles);
        // Load the pixels to a local buffer
        var pixels = try allocator.alloc(Color, image.width * image.height);
        defer allocator.free(pixels);
        var color_it = image.iterator();
        var idx: usize = 0;
        while (color_it.next()) |pixel| : (idx += 1) {
            pixels[idx] = .{ .r = @intFromFloat(pixel.r * 255), .g = @intFromFloat(pixel.g * 255), .b = @intFromFloat(pixel.b * 255) };
        }
        // Generate tile colors
        for (tiles, 0..) |*tile, i| {
            // Allocate new colors for the tile
            const colors = try allocator.alloc(Color, tile_size * tile_size);
            errdefer allocator.free(colors);
            // Read the colors from the pixels array
            var colors_idx: usize = 0;
            for (0..tile_size) |dy| {
                const y: usize = (i / image.height + dy) % image.height;
                for (0..tile_size) |dx| {
                    const x: usize = (i % image.width + dx) % image.width;
                    const pixels_idx: usize = y * image.width + x;
                    const color = &pixels[pixels_idx];
                    colors[colors_idx] = .{ .r = color.r, .g = color.g, .b = color.b };
                    colors_idx += 1;
                }
            }
            // Finalize the new tile
            tile.* = .{ .colors = colors, .freq = 0 };
        }
        return tiles;
    }

    pub fn deinit(self: *const Tile, allocator: *const std.mem.Allocator) void {
        allocator.free(self.colors);
    }

    pub fn color_hash(self: *const Tile) u64 {
        var hasher = std.hash.Wyhash.init(0);
        for (self.colors) |col| {
            std.hash.autoHash(&hasher, col);
        }
        return hasher.final();
    }
};
