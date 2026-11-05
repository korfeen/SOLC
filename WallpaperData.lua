-- Made by tools/gen-wallpaper.js: each wallpaper's true shape (its tile's width / height, and its border's), for
-- drawing the textures in Media/Wallpaper (squashed to powers of two) unsquashed.
local _, ns = ...

ns.WALLPAPERS = {
    blocks = { aspect = 1, border = 4, plain = { { 0.002, 0.191, 0.256 }, { 0.004, 0.307, 0.414 }, { 0.928, 0.917, 0.893 } } },
    floral_orange = { aspect = 1, border = 4, plain = { { 0.574, 0.270, 0.024 }, { 0.926, 0.435, 0.038 }, { 0.965, 0.808, 0.586 } } },
    floral_yellow = { aspect = 1, border = 4, plain = { { 0.564, 0.322, 0.016 }, { 0.910, 0.519, 0.026 }, { 0.969, 0.912, 0.781 } } },
    fruit = { aspect = 1, border = 4, plain = { { 0.527, 0.403, 0.302 }, { 0.850, 0.650, 0.486 }, { 0.986, 0.916, 0.834 } } },
    loops = { aspect = 1.0047, border = 4, plain = { { 0.435, 0.275, 0.128 }, { 0.702, 0.443, 0.206 }, { 0.767, 0.665, 0.523 } } },
    ogee = { aspect = 2.0769, border = 4, plain = { { 0.589, 0.387, 0.070 }, { 0.951, 0.623, 0.113 }, { 0.969, 0.924, 0.813 } } },
    stripes = { aspect = 1, border = 4, plain = { { 0.181, 0.125, 0.083 }, { 0.292, 0.201, 0.134 }, { 0.292, 0.201, 0.134 } } },
}
