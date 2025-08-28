package rlgrid

import "core:math"
import "core:math/linalg"

import rl "vendor:raylib"

/**
 * 
 * This package is for rendering to/from grid coordinates to other grid coordinates
 * 
 * If you are working with some type of tile based game, or know of some kind of "unit" by which you are doing your measurements, it can be useful to use some conceptual grid as opposed to just pixel amounts
 * 
 */


Horizontal_Justification :: enum 
{
    Left,
    Right,
    Centered,
}

Vertical_Justification :: enum 
{
    Top,
    Bottom,
    Centered,
}


get_rectangle_on_grid :: proc(rectangle : rl.Rectangle, cell_size : f32) -> rl.Rectangle 
{
    ret := rl.Rectangle{rectangle.x * cell_size, rectangle.y * cell_size, rectangle.width * cell_size, rectangle.height * cell_size}

    return ret
}


draw_rectangle_on_grid :: proc(rectangle : rl.Rectangle, color : rl.Color, cell_size : f32) 
{
    render_rectangle := get_rectangle_on_grid(rectangle, cell_size)
    rl.DrawRectangleRec(render_rectangle, color)
}

draw_rectangle_on_grid_right_justified :: proc(rectangle : rl.Rectangle, color : rl.Color, cell_size : f32) 
{
    justified_rectangle := rectangle
    justified_rectangle.x -= rectangle.width
    render_rectangle := get_rectangle_on_grid(justified_rectangle, cell_size)
    rl.DrawRectangleRec(render_rectangle, color)
}

draw_rectangle_on_grid_center_justified :: proc(r : rl.Rectangle, color : rl.Color, cell_size : f32) 
{
    justified_r := r
    justified_r.x -= r.width / 2
    render_r := get_rectangle_on_grid(justified_r, cell_size)
    rl.DrawRectangleRec(render_r, color)
}


draw_rectangle_on_grid_justified :: proc(
    r : rl.Rectangle,
    color : rl.Color,
    cell_size : f32,
    horizontal_justification : Horizontal_Justification = .Left,
    vertical_justification : Vertical_Justification = .Top,
) 
{
    justified_rectangle := r
    switch horizontal_justification 
    {
    case .Right:
        
        {
            justified_rectangle.x -= r.width
        }
    case .Centered:
        
        {
            justified_rectangle.x -= r.width / 2
        }
    case .Left:
        
        {}
    }
    switch vertical_justification 
    {
    case .Bottom:
        
        {
            justified_rectangle.y -= r.height
        }
    case .Centered:
        
        {
            justified_rectangle.y -= r.height / 2
        }
    case .Top:
        
        {}

    }

    draw_rectangle_on_grid(justified_rectangle, color, cell_size)
}

draw_rectangle_lines_on_grid :: proc(rectangle : rl.Rectangle, line_thick : f32, color : rl.Color, cell_size : f32) 
{
    render_rectangle := get_rectangle_on_grid(rectangle, cell_size)
    rl.DrawRectangleLinesEx(render_rectangle, line_thick, color)
}


get_grid_cell_rectangle :: proc(grid_pos : [2]f32, cell_size : f32) -> rl.Rectangle 
{
    ret := rl.Rectangle{grid_pos.x * cell_size, grid_pos.y * cell_size, cell_size, cell_size}

    return ret
}

get_actual_pos :: proc(grid_pos : [2]f32, cell_size : f32) -> [2]f32
{
    ret := grid_pos * cell_size
    return ret
}


actual_pos_to_grid_pos :: proc(actual_pos : [2]f32, cell_size : f32) -> [2]f32
{
    ret := actual_pos / cell_size
    return ret
}

draw_sprite_sheet_clip_on_grid :: proc(sprite_sheet : rl.Texture2D, src_grid_pos, dst_grid_pos : [2]f32, src_cell_size, dst_cell_size, rotation : f32) 
{
    src_rect := get_grid_cell_rectangle(src_grid_pos, src_cell_size)
    dst_rect := get_grid_cell_rectangle(dst_grid_pos, dst_cell_size)
    dst_midpoint := [2]f32{dst_rect.width / 2, dst_rect.height / 2}
    dst_rect.x += dst_midpoint.x
    dst_rect.y += dst_midpoint.y
    rl.DrawTexturePro(sprite_sheet, src_rect, dst_rect, [2]f32{dst_midpoint.x, dst_midpoint.y}, rotation, rl.WHITE)
}


/** draw_grid_texture_clip_on_grid 
 * 
 * terms:
 * - clip: A rectangular subsection of a larger texture. For example, a sprite sheet has many sprites in it, and you just want one, so you take a clip from it
 * - render target: Whatever canvas you are drawing on.
 * - texture: an image loaded onto GPU
 *
 * inputs:
 * - tex: Source Texture to take a clip out of
 * - src_rectangle: The clip dimensions in grid coordinates of the source texture's grid
 * - src_grid_cell_size: The cell size of the source texture's grid. For example, maybe the sprites each take up 16 x 16 pixels. In this case, src_grid_cell_size will be 16
 * - dst_rectangle: The destination that the clip should be drawn at on wherever the render target is pointing to. If the dst_rectangle is smaller than the src_rectangle, the sprite will be shrunk. If the dst_rectangle is larger than the src_rectangle, then it will be stretched larger. 
 * - dst_grid_cell_size: The cell size of the render target's grid. So if we are rendering to a grid where each cell is 32 x 32 pixels, the value will be 32
 * - rotation: the rotation in degrees to rotate the sprite on the render target
 * 
 * **/
draw_grid_texture_clip_on_grid :: proc(
    tex : rl.Texture2D,
    src_rectangle : rl.Rectangle,
    src_grid_cell_size : f32,
    dst_rectangle : rl.Rectangle,
    dst_grid_cell_size, rotation : f32,
    flip_x : bool = false,
    flip_y : bool = false,
) 
{
    src_rect := get_rectangle_on_grid(src_rectangle, src_grid_cell_size)
    if flip_x 
    {
        src_rect.width = -src_rect.width
    }
     else if flip_y 
    {
        src_rect.height = -src_rect.height
    }

    dst_rect := get_rectangle_on_grid(dst_rectangle, dst_grid_cell_size)
    rotation_origin := [2]f32{dst_rect.width / 2, dst_rect.height / 2}
    dst_rect.x += rotation_origin.x
    dst_rect.y += rotation_origin.y
    dst_rect.x = math.round(dst_rect.x)
    dst_rect.y = math.round(dst_rect.y)

    // rl.DrawCircleV(rotation_origin, 5, rl.RED)
    rl.DrawTexturePro(tex, src_rect, dst_rect, rotation_origin, rotation, rl.WHITE)
    // rl.DrawCircleV([2]f32{dst_rect.x, dst_rect.y}, 5, rl.RED)
    // rl.DrawLineV(rotation_origin, [2]f32{dst_rect.x, dst_rect.y}, rl.WHITE)

}


draw_text_on_grid :: proc(font : rl.Font, text : cstring, pos : [2]f32, size : f32, spacing : f32, tint : rl.Color, grid_cell_size : f32) 
{
    dst_pos := [2]f32{pos.x * grid_cell_size, pos.y * grid_cell_size}
    dst_spacing := spacing * grid_cell_size
    dst_size := size * grid_cell_size
    rl.DrawTextEx(font, text, dst_pos, dst_size, dst_spacing, tint)
}


draw_text_on_grid_right_justified :: proc(font : rl.Font, text : cstring, pos : [2]f32, size, spacing : f32, tint : rl.Color, grid_cell_size : f32) 
{
    text_dimensions := rl.MeasureTextEx(font, text, size, spacing)
    dst_pos := [2]f32{pos.x - f32(text_dimensions.x), pos.y}
    draw_text_on_grid(font, text, dst_pos, size, spacing, tint, grid_cell_size)
}

draw_text_on_grid_centered :: proc(font : rl.Font, text : cstring, pos : [2]f32, size, spacing : f32, tint : rl.Color, grid_cell_size : f32) 
{
    text_dimensions := rl.MeasureTextEx(font, text, size, spacing)
    dst_pos := [2]f32{pos.x - f32(text_dimensions.x) / 2, pos.y}
    draw_text_on_grid(font, text, dst_pos, size, spacing, tint, grid_cell_size)
}


draw_text_on_grid_with_background :: proc(
    font : rl.Font,
    text : cstring,
    pos : [2]f32,
    size : f32,
    grid_cell_size : f32,
    spacing : f32 = 0.0,
    text_tint : rl.Color = rl.WHITE,
    background_color : rl.Color = rl.BLACK,
    horizontal_text_justification : Horizontal_Justification = .Left,
    vertical_text_justification : Vertical_Justification = .Top,
) 
{
    text_dimensions := rl.MeasureTextEx(font, text, size, spacing)
    render_pos := pos
    switch vertical_text_justification 
    {
    case .Top:
        
        {}
    case .Bottom:
        
        {
            render_pos.y -= size
        }
    case .Centered:
        
        {
            render_pos.y -= size / 2
        }
    }
    r := rl.Rectangle{render_pos.x, render_pos.y, text_dimensions.x, text_dimensions.y}
    switch horizontal_text_justification 
    {
    case .Left:
        
        {
            draw_rectangle_on_grid(r, background_color, grid_cell_size)
            draw_text_on_grid(font, text, render_pos, size, spacing, text_tint, grid_cell_size)
        }
    case .Right:
        
        {
            draw_rectangle_on_grid_right_justified(r, background_color, grid_cell_size)
            draw_text_on_grid_right_justified(font, text, render_pos, size, spacing, text_tint, grid_cell_size)

        }
    case .Centered:
        
        {
            draw_rectangle_on_grid_center_justified(r, background_color, grid_cell_size)
            draw_text_on_grid_centered(font, text, render_pos, size, spacing, text_tint, grid_cell_size)
        }
    }
}


draw_circle_on_grid :: proc(pos : [2]f32, r : f32, color : rl.Color, grid_cell_size : f32)
{
    _pos := pos * grid_cell_size
    _r := r * grid_cell_size
    rl.DrawCircleV(_pos, _r, color)
}


draw_line_on_grid :: proc(start_pos : [2]f32, end_pos : [2]f32, thickness : f32, color : rl.Color, grid_cell_size : f32)
{
    _start_pos := start_pos * grid_cell_size
    _end_pos := end_pos * grid_cell_size
    _thickness := thickness * grid_cell_size
    rl.DrawLineEx(_start_pos, _end_pos, _thickness, color)
}


degrees_to_radians :: proc(degrees : f32) -> f32
{
    radians := degrees * (math.TAU / 360.0)
    return radians
}

radians_to_degrees :: proc(radians : f32) -> f32
{
    degrees := radians * (360 / math.TAU)
    return degrees
}


draw_arrow_on_grid :: proc(start, end: [2]f32, thickness : f32, color : rl.Color, grid_cell_size : f32) {
    // 1. Draw main line
    draw_line_on_grid(start, end, thickness, color, grid_cell_size)

    //, thickness, grid_cell_size 2. Direction vector
    dir := end - start
    // dir_norm := [2]f32{1,1}
    dir_norm := linalg.normalize(dir)

    // 3. Arrowhead angle (30 degrees in radians)
    arrow_angle := degrees_to_radians(30.0)
    arrow_len   : f32 = 0.3

    // 4. Rotate dir by +angle
    left := [2]f32{
        dir_norm.x * math.cos(arrow_angle) - dir_norm.y * math.sin(arrow_angle),
        dir_norm.x * math.sin(arrow_angle) + dir_norm.y * math.cos(arrow_angle),
    }

    // 5. Rotate dir by -angle
    right := [2]f32{
        dir_norm.x * math.cos(-arrow_angle) - dir_norm.y * math.sin(-arrow_angle),
        dir_norm.x * math.sin(-arrow_angle) + dir_norm.y * math.cos(-arrow_angle),
    }

    // 6. Scale by arrow_len and draw from end
    draw_line_on_grid(end, end - left * arrow_len, thickness, color, grid_cell_size)
    draw_line_on_grid(end, end - right * arrow_len, thickness, color, grid_cell_size)
}


