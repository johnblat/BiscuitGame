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


Sprite_Clip_Name :: enum {
    Status_Miss,
    Status_Hit,
    Spacebar_Down,
    Spacebar_Up,
    Play_Button_Up,
    Play_Button_Down,
    Credits_Button_Up,
    Credits_Button_Down,
    Back_Button_Up,
    Back_Button_Down,

}


Sprite_Clip :: struct
{
    tex_id : Texture_Id,
    clip_rectangle : rl.Rectangle,
}

global_sprite_clips := [Sprite_Clip_Name]Sprite_Clip{
    .Status_Miss = { tex_id = .Statuses_Sprite_Sheet, clip_rectangle = rl.Rectangle{2,0,1,1} },
    .Status_Hit = { tex_id = .Statuses_Sprite_Sheet, clip_rectangle = rl.Rectangle{0,0,1,1} },
    .Spacebar_Down = {tex_id = .Spacebar_Sprite_Sheet, clip_rectangle = rl.Rectangle{2.5,0, 2.5, 1}},
    .Spacebar_Up = { tex_id = .Spacebar_Sprite_Sheet, clip_rectangle = rl.Rectangle{0,0, 2.5, 1}},

    .Play_Button_Up = { tex_id = .Play_Button_Spritesheet, clip_rectangle = rl.Rectangle{0,0,3,1}},
    .Play_Button_Down = { tex_id = .Play_Button_Spritesheet, clip_rectangle = rl.Rectangle{0,1,3,1}},

    .Back_Button_Up = { tex_id = .Back_Button_Spritesheet, clip_rectangle = rl.Rectangle{0,0,3,1}},
    .Back_Button_Down = { tex_id = .Back_Button_Spritesheet, clip_rectangle = rl.Rectangle{0,1,3,1}},

    .Credits_Button_Up = { tex_id = .Credits_Button_Spritesheet, clip_rectangle = rl.Rectangle{0,0,3,1}},
    .Credits_Button_Down = { tex_id = .Credits_Button_Spritesheet, clip_rectangle = rl.Rectangle{0,1,3,1}},

}


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
    rectangle_clip := global_sprite_clips[sprite_clip].clip_rectangle
    tex_sprite_sheet_id := global_sprite_clips[sprite_clip].tex_id
    tex := gmem.textures[tex_sprite_sheet_id]

    rlgrid.draw_grid_texture_clip_on_grid(tex, rectangle_clip, global_sprite_sheet_cell_size, dst_rectangle, dst_grid_cell_size, rotation, flip_x, flip_y)
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
    rectangle_clip := global_sprite_clips[sprite_clip].clip_rectangle

    dst_rectangle := rl.Rectangle{pos.x, pos.y, rectangle_clip.width * scale_x, rectangle_clip.height * scale_y}
    
    tex_sprite_sheet_id := global_sprite_clips[sprite_clip].tex_id
    tex := gmem.textures[tex_sprite_sheet_id]

    rlgrid.draw_grid_texture_clip_on_grid(
        tex,
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
