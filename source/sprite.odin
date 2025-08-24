package game

import rlgrid "./rlgrid"
import "core:math"
import rl "vendor:raylib"


Animation_Player :: struct 
{
    t :              f32,
    is_playing :     f32,
    is_looping :     bool,
    fps :            f32,
    animation_name : Animation_Name,
}


Sprite_Clip_Name :: enum {}
global_sprite_clips := [Sprite_Clip_Name]rl.Rectangle{}

Animation_Name :: enum {}
global_sprite_animations := [Animation_Name][]Sprite_Clip_Name{}

Animation_Player_Name :: enum {}
global_animation_players := [Animation_Player_Name]Animation_Player{}


animation_get_current_frame :: proc(t, fps : f32, number_of_frames : int) -> int 
{
    ret := int(math.mod(t * fps, f32(number_of_frames)))
    return ret
}


animation_get_duration :: proc(fps : f32, number_of_frames : int) -> f32 
{
    ret := f32(number_of_frames) / fps
    return ret
}


animation_get_frame_sprite_clip :: proc(t, fps : f32, frame_clips : []rl.Rectangle) -> rl.Rectangle 
{
    frame_index := animation_get_current_frame(t, fps, len(frame_clips))
    frame_clip_rectangle := frame_clips[frame_index]
    return frame_clip_rectangle
}


animation_get_frame_sprite_clip_id :: proc(t, fps : f32, frame_clips : []Sprite_Clip_Name) -> Sprite_Clip_Name 
{
    frame_index := animation_get_current_frame(t, fps, len(frame_clips))
    frame_clip := frame_clips[frame_index]
    return frame_clip
}

// These are here because not common to rlgrid, they are application code as opposed to library because i may not re-use the above 

draw_sprite_sheet_clip_on_grid :: proc(
    sprite_clip : Sprite_Clip_Name,
    dst_rectangle : rl.Rectangle,
    dst_grid_cell_size, rotation : f32,
    flip_x : bool = false,
    flip_y : bool = false,
) 
{
    rectangle_clip := global_sprite_clips[sprite_clip]
    rlgrid.draw_grid_texture_clip_on_grid(gmem.texture_sprite_sheet, rectangle_clip, global_sprite_sheet_cell_size, dst_rectangle, dst_grid_cell_size, rotation, flip_x, flip_y)
}

draw_sprite_sheet_clip_on_game_texture_grid :: proc(
    sprite_clip : Sprite_Clip_Name,
    pos : [2]f32,
    rotation : f32 = 0.0,
    scale_x : f32 = 1.0,
    scale_y : f32 = 1.0,
    flip_x : bool = false,
    flip_y : bool = false,
) 
{
    rectangle_clip := global_sprite_clips[sprite_clip]
    dst_rectangle := rl.Rectangle{pos.x, pos.y, rectangle_clip.width * scale_x, rectangle_clip.height * scale_y}
    rlgrid.draw_grid_texture_clip_on_grid(
        gmem.texture_sprite_sheet,
        rectangle_clip,
        global_sprite_sheet_cell_size,
        dst_rectangle,
        global_game_texture_grid_cell_size,
        rotation,
        flip_x,
        flip_y,
    )
}

draw_sprite_sheet_clip_on_game_texture_grid_from_animation_player :: proc(
    animation_player : Animation_Player,
    pos : [2]f32,
    rotation : f32 = 0.0,
    scale_x : f32 = 1.0,
    scale_y : f32 = 1.0,
    flip_x : bool = false,
    flip_y : bool = false,
) 
{
    clip_name := animation_get_frame_sprite_clip_id(animation_player.t, animation_player.fps, global_sprite_animations[animation_player.animation_name])
    draw_sprite_sheet_clip_on_game_texture_grid(clip_name, pos, rotation, scale_x, scale_y, flip_x, flip_y)
}
