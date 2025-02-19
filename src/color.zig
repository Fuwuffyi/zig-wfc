pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn eql(a: Color, b: Color) bool {
        return a.r == b.r and a.g == b.g and a.b == b.b;
    }
};
