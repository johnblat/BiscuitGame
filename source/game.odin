package game

import "base:intrinsics"
import "core:c"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import rl "vendor:raylib"

import rlgrid "./rlgrid"

bytes_font_data := #load("../assets/joystix monospace.otf")

bytes_png_giant_biscuit := #load("../assets/giant-biscuit.png")
bytes_png_regular_biscuit := #load("../assets/half-sized-biscuit.png")
bytes_png_person := #load("../assets/Person_Passing.png")
bytes_png_cannon := #load("../assets/canon.png")
bytes_png_unicycle1 := #load("../assets/unicycle1.png")
bytes_png_rope := #load("../assets/rope.png")
bytes_png_shark := #load("../assets/shark2.png")
bytes_png_georgie := #load("../assets/georgie.png")
bytes_png_reticle := #load("../assets/reticle.png")
bytes_png_bumper_circus := #load("../assets/bumper_circus.png")
bytes_png_bumper_unicycle := #load("../assets/bumper_unicycle.png")
bytes_png_statuses := #load("../assets/status.png")
bytes_png_spacebar_spritesheet := #load("../assets/spacebar-prompt.png")
bytes_png_play_button_spritesheet := #load("../assets/play_button.png")
bytes_png_credits_button_spritesheet := #load("../assets/credits_button.png")
bytes_png_back_button_spritesheet := #load("../assets/back_button.png")
bytes_png_credits := #load("../assets/credits.png")
bytes_png_menu_bg := #load("../assets/menu_bg.png")
bytes_png_framing_decorations := #load("../assets/framing_decorations.png")



global_filename_window_save_data := "window_save_data.jam"
global_game_view_pixels_width : f32 = 1280 / 2
global_game_view_pixels_height : f32 = 720 / 2
global_game_texture_grid_cell_size : f32 = 32
global_number_grid_cells_axis_x : f32 = global_game_view_pixels_width / global_game_texture_grid_cell_size
global_number_grid_cells_axis_y : f32 = global_game_view_pixels_height / global_game_texture_grid_cell_size
global_sprite_sheet_cell_size : f32 = 32




Window_Save_Data :: struct 
{
    x, y, width, height : i32,
}


Root_State :: enum 
{
    Main_Menu,
    Game,
    Bumper,
}


Result_Status :: enum
{
	None,
	Hit,
	Missed,
}

Game_Memory :: struct 
{
    root_state :                          Root_State,

	entities : Handle_Array(Entity, Entity_Handle),
	first_biscuit_parent_h : Entity_Handle,


    music :                               rl.Music,
    clap_sound : rl.Sound,
    ready_sound : rl.Sound,

    pop_sound : rl.Sound,

	track_time_ms_previous : u64,
	music_bpm : f32,

	virtual_mouse_previous : [2]f32,

    // VIEW
    game_render_target :                  rl.RenderTexture,
    overlay_image : rl.Image,
    overlay_tex : rl.Texture,

    // TODO(jblat): not filled with anything
    texture_sprite_sheet :                rl.Texture,
    rectangle :                           rl.Rectangle,
    rectangle_color :                     rl.Color,
    rectangle_lerp_position :             Lerp_Position,

	textures : [Texture_Id]rl.Texture,

	camera : rl.Camera2D,

    // Font
    font :                                rl.Font,

    // bumper
    bumper_sparkle_sound : rl.Sound,
    bumper_fade_in_timer : f32,
    bumper_fade_out_timer : f32,
    bumper_texture : Texture_Id,
    bumper_voice : rl.Sound,
    bumper_did_voice_start : bool,

    // DEBUG
    dbg_show_grid :                       bool,
    dbg_show_level :                      bool,
    dbg_is_frogger_unkillable :           bool,
    dbg_show_entity_bounding_rectangles : bool,
    dbg_speed_multiplier :                f32,
    dbg_camera_offset :                   [2]f32,
    dbg_camera_zoom :                     f32,
    pause :                               bool,

    //
    main_menu_show_credits : bool,
    main_menu_any_button_hovered_previous : bool,
}




Load_Texture_Description :: struct 
{
	tex_id : Texture_Id,
	bytes_png : []u8,
}

Texture_Id :: enum {
	None,
	Person,
	Giant_Biscuit,
	Regular_Biscuit,
	Cannon,
	Unicycle1,
	Rope_Ladder,
	Shark,
	Georgie,
	Reticle,
	Bumper_Circus,
	Bumper_Unicycle,
	Statuses_Sprite_Sheet,
	Spacebar_Sprite_Sheet,
	Play_Button_Spritesheet,
	Back_Button_Spritesheet,
	Credits_Button_Spritesheet,
	Credits,
	Menu_Bg,
	Framing_Decoration,
}


Sprite_Data :: union 
{
	Texture_Id,
	Sprite_Clip_Name,
}


Behavior :: enum {
	Face_Biscuit,
	Is_Biscuit,
	Move_Veritcally_On_Parent,
	Auto_Pass,
	Moveable,
	Hazard,
	Flip_V,
	Orbiting_Around_Parent,
	Swing_Around_Parent,
	Shoot_In_Direction,
	Music_Event,
	Music_Auto_Pass,
	Play_Sound_Event,
}


// thinking that maybe there is different pass behavior. not used
Pass_Behavior :: enum {
	Auto_Target_Next_Entity,
	Shoot_In_Direction,
}


Entity_Handle :: distinct Handle

Root_Entity_Handle :: Entity_Handle{idx = 0, gen = 0}


Entity :: struct
{
	handle : Entity_Handle,
	parent_entity_handle : Entity_Handle,

	vel : [2]f32,
	pos : [2]f32,
	speed : f32,
	collider : rl.Rectangle,

	sprite_data : Sprite_Data,

	next_entity_handle: Entity_Handle,

	lerp_pos : Lerp_Position,

	behaviors : bit_set[Behavior],
	
	veritcal_move_bounds : f32,
	
	wait_timer : f32,
	wait_timer_duration : f32,
	

	orbiting_dir : i32, // + or -
	orbiting_distance : f32,
	orbiting_angle : f32,

	swing_angle_start : f32,
	swing_angle_end : f32,

	aim_angle : f32,

	status : Result_Status,

	/**
	 *  How this will work for now is that we query the current time in the track.
	 * We also store the 'previous' track time in the Game_Memory. This gives us an 'unplayed musical event window'
	 * 
	 *                                previous track time         current track time
	 *                                                v             v
	 * unplayed window: |                             |             |                                         |
	 * event in order:  e    e     e     e       e       e            e    e e e e         e  e      e        e
	 * 
	 *                                                          |  hit  |
	 * 
	 *                  |                             |             |                                         |
	 *                  |  events that already played | will play - |    future stuff that didnt happen yet   |
     *                                                 during this -
     *                                                 frame
     * 
     * while it is possible for one event that follows another plays during the same frame, it is very unlikely because the previous and current are very close together
     * It is really a way to keep a moving window so that we can find an event within that window to play.
     * This is because frames in the audio track will happen at a much faster rate than frames in the game.
     */
	// why 96? Cause 96 its a multiple of 1, 2, 4, 8, 16, and 32. Even 24. Its standard in MIDI to use this as a base number for abstract musical ticks. 
	delta_time_in_music_ticks : u64, // 0 = same time as last event (must be first). 96 = quarter note since last event.  96/2 = eighth note since last event. You get idea.

}


gmem : ^Game_Memory


biscuit_h : Entity_Handle


// TIME


sec_to_ms :: proc(sec : f32) -> u64
{
	ms_f := sec * 1000
	ms := u64(ms_f)
	return ms
}


ms_to_sec :: proc(ms : u64) -> f32
{
	sec := f32(ms) / 1000.0
	return sec
}


// MATH


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


// ENTITY


set_parent :: proc(entity_handle, parent_entity_handle : Entity_Handle)
{
	if entity_handle == {} 
	{
		return	// get out
	}  
	e_ptr := ha_get_ptr(gmem.entities, entity_handle)
	e_ptr.parent_entity_handle = parent_entity_handle
}


set_next_entity :: proc(entity_handle, next_entity_handle : Entity_Handle)
{
	if entity_handle == {} do return
	ptr := ha_get_ptr(gmem.entities, entity_handle)
	ptr.next_entity_handle = next_entity_handle
}


entity_get_root_pos :: proc(handle : Entity_Handle) -> [2]f32
{
	
	entity, _ := ha_get(gmem.entities, handle)
	root_pos := entity.pos
	
	parent_entity_handle := entity.parent_entity_handle
	parent_entity := Entity{}

	if handle == parent_entity_handle
	{
		// parent is itself, so... yeah, we just treat this that its the root
		return root_pos
	}

	for parent_entity_handle.idx != 0
	{
		parent_entity, _ = ha_get(gmem.entities, parent_entity_handle)
		root_pos += parent_entity.pos
		parent_entity_handle = parent_entity.parent_entity_handle
	}

	return root_pos
}


entity_get_root_collider :: proc(handle : Entity_Handle) -> rl.Rectangle
{
	root_pos := entity_get_root_pos(handle)
	e, _ := ha_get(gmem.entities, handle)
	collider := e.collider
	root_collider := rl.Rectangle {
		root_pos.x + collider.x,
		root_pos.y + collider.y,
		collider.width,
		collider.height,
	}
	return root_collider
}


entity_root_pos_to_relative_pos :: proc(root_pos : [2]f32, relative_to_handle : Entity_Handle) -> [2]f32
{
	relative_root_pos := entity_get_root_pos(relative_to_handle)
    return root_pos - relative_root_pos
}


entity_find_first_matching_behavior :: proc(behaviors : bit_set[Behavior]) -> Entity_Handle
{
	entity_iter := ha_make_iter(gmem.entities)
	for entity, handle in ha_iter(&entity_iter)
	{
		if behaviors == entity.behaviors
		{
			return handle
		}
	}
	
    return Entity_Handle{}
}


create_entity_ring :: proc(handles_ordered : []Entity_Handle)
{
	for i := 0; i < len(handles_ordered); i+=1
	{
		next_i := (i + 1) % len(handles_ordered) // treat it like a ring for now
		this_h := handles_ordered[i]
		next_h := handles_ordered[next_i]
		set_next_entity(this_h, next_h)
	}
}


create_entity :: proc(entity : Entity) -> Entity_Handle
{	
	new_handle := ha_add(&gmem.entities, entity)
	ptr := ha_get_ptr(gmem.entities, new_handle)
	ptr.handle = new_handle
	return new_handle
}


// LEVEL CREATION


create_level_1 :: proc()
{
	ha_clear(&gmem.entities)

	av1_h := ha_add(&gmem.entities, Entity { pos = [2]f32{18, 4}, veritcal_move_bounds = 5}) // anchor for next entity
	ha_add(&gmem.entities, Entity{ parent_entity_handle = av1_h, pos = [2]f32{0,0}, sprite_data = .Rope_Ladder, })
	ha_add(&gmem.entities, Entity{ parent_entity_handle = av1_h, pos = [2]f32{0,1}, sprite_data = .Rope_Ladder, })
	ha_add(&gmem.entities, Entity{ parent_entity_handle = av1_h, pos = [2]f32{0,2}, sprite_data = .Rope_Ladder, })
	ha_add(&gmem.entities, Entity{ parent_entity_handle = av1_h, pos = [2]f32{0,3}, sprite_data = .Rope_Ladder, })
	ha_add(&gmem.entities, Entity{ parent_entity_handle = av1_h, pos = [2]f32{0,4}, sprite_data = .Rope_Ladder, })

	av2_h := ha_add(&gmem.entities, Entity { pos = [2]f32{24, 5}, veritcal_move_bounds = 3}) // anchor for next

	e1_h := ha_add(&gmem.entities, Entity { pos = [2]f32{4, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit}})
	e2_h := ha_add(&gmem.entities, Entity { pos = [2]f32{6, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit}})
	// e2_h := ha_add(&gmem.entities, Entity { pos = [2]f32{6, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Shoot_In_Direction}, aim_angle = degrees_to_radians(270)})
	e3_h := ha_add(&gmem.entities, Entity { pos = [2]f32{8, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit}})
	e4_h := ha_add(&gmem.entities, Entity { pos = [2]f32{10, 5}, sprite_data = .Person,  behaviors = {.Face_Biscuit}})
	e5_h := ha_add(&gmem.entities, Entity { pos = [2]f32{12, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit}})
	e6_h := ha_add(&gmem.entities, Entity { pos = [2]f32{14, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit}})
	e7_h := ha_add(&gmem.entities, Entity { pos = [2]f32{16, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit}})
	e8_h := ha_add(&gmem.entities, Entity { pos = [2]f32{20, 6}, sprite_data = .Cannon,  behaviors = {.Auto_Pass, .Face_Biscuit}, wait_timer_duration = 0.25,})
	e9_h := ha_add(&gmem.entities, Entity { pos = [2]f32{22, 6}, sprite_data = .Unicycle1,  behaviors = {.Moveable, .Face_Biscuit}, speed = 6})
	e10_h := ha_add(&gmem.entities, Entity { pos = [2]f32{26, 6}, sprite_data = .Person, behaviors = {.Face_Biscuit}})
	e11_h := ha_add(&gmem.entities, Entity { pos = [2]f32{0, 0}, sprite_data = .Person, behaviors = {.Face_Biscuit, .Move_Veritcally_On_Parent}, speed = 4})

	h1_h := ha_add(&gmem.entities, Entity { pos = [2]f32{0, 0}, sprite_data = .Shark, behaviors = {.Hazard, .Move_Veritcally_On_Parent, .Flip_V}, collider = rl.Rectangle{0,0,1,1}, speed = 3 })
	set_next_entity(h1_h, e1_h)
	g_h := ha_add(&gmem.entities, Entity { pos = [2]f32{0,0}, sprite_data = .Georgie, behaviors = {.Orbiting_Around_Parent}, speed = 2, orbiting_dir = +1, orbiting_distance = 3})
	set_parent(g_h, e1_h)

	swingin_g_h := ha_add(&gmem.entities, Entity { pos = [2]f32{0,0}, sprite_data = .Georgie, behaviors = {.Orbiting_Around_Parent, .Swing_Around_Parent}, speed = 2, orbiting_dir = +1, orbiting_distance = 3, swing_angle_end = degrees_to_radians(180 - 10), swing_angle_start = degrees_to_radians(0 + 10)})
	set_parent(swingin_g_h, e4_h)

	set_parent(e11_h, av1_h)
	set_parent(h1_h, av2_h)


	biscuit_h = ha_add(&gmem.entities, Entity { parent_entity_handle = e1_h, pos = [2]f32{0,0}, sprite_data =.Regular_Biscuit, behaviors = { .Is_Biscuit }, collider = rl.Rectangle { 0.33, 0.33, 0.33, 0.33} })
	set_parent(biscuit_h, e1_h)
	gmem.first_biscuit_parent_h = e1_h

	pass_ring := [?]Entity_Handle{e1_h, swingin_g_h, e2_h, e3_h, e4_h, e5_h, e6_h, e7_h, e11_h, e8_h, e9_h, e10_h, }
	
	create_entity_ring(pass_ring[:])

}



/**
 * This will take in a cursor as the starting point to start placing entities.
 * It will place the first entity at the starting point and then after creating an entity, it will move the next entity along the vector.
 * At the end, it will return the position of the cursor where the next entity would go
 */
create_entities_with_cursor_and_set_next :: proc(cursor_start : [2]f32, previous_handle : Entity_Handle, vector_to_each_new_entity_pos : [2]f32, entities : ..Entity) -> (end_cursor : [2]f32, start_handle : Entity_Handle, end_handle : Entity_Handle)
{
	if len(entities) == 0 do return cursor_start, {}, {}

	cursor := cursor_start

	entity_current := entities[0]
	entity_current.pos = cursor
	current_handle := ha_add(&gmem.entities, entity_current)
	start_handle = current_handle
	set_next_entity(previous_handle, start_handle)
	
	cursor += vector_to_each_new_entity_pos

	entity_previous := entity_current
	previous_handle := current_handle

	for i in 1..<len(entities)
	{
		entity_current = entities[i]
		entity_current.pos = cursor
		cursor += vector_to_each_new_entity_pos

		current_handle = create_entity(entity_current)
		set_next_entity(previous_handle, current_handle )
		previous_handle = current_handle

	}

	end_handle = current_handle

	return cursor, start_handle, end_handle
}


create_level_2 :: proc()
{
	ha_clear(&gmem.entities)



	e1_h := ha_add(&gmem.entities, Entity { pos = [2]f32{4, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96,}) // 2
	e2_h := ha_add(&gmem.entities, Entity { pos = [2]f32{6, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2}) // 4
	e3_h := ha_add(&gmem.entities, Entity { pos = [2]f32{8, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2}) // 2
	e4_h := ha_add(&gmem.entities, Entity { pos = [2]f32{10, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2}) // 4
	e6_h := ha_add(&gmem.entities, Entity { pos = [2]f32{12, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event, .Play_Sound_Event}, delta_time_in_music_ticks = 96*2}) // 2
	e7_h := ha_add(&gmem.entities, Entity { pos = [2]f32{14, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event, }, delta_time_in_music_ticks = 96*2}) // 4
	

	e10_h := ha_add(&gmem.entities, Entity { pos = [2]f32{18, 6}, sprite_data = .Unicycle1,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2}) // 2
	e12_h := ha_add(&gmem.entities, Entity { pos = [2]f32{20, 6}, sprite_data = .Unicycle1,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96}) // 3
	e13_h := ha_add(&gmem.entities, Entity { pos = [2]f32{22, 6}, sprite_data = .Unicycle1,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96}) // 4

	e14_h := ha_add(&gmem.entities, Entity { pos = [2]f32{24, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2}) // 2
	e16_h := ha_add(&gmem.entities, Entity { pos = [2]f32{26, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2}) // 4
	e17_h := ha_add(&gmem.entities, Entity { pos = [2]f32{28, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2}) // 2
	e18_h := ha_add(&gmem.entities, Entity { pos = [2]f32{30, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2}) // 4
	e19_h := ha_add(&gmem.entities, Entity { pos = [2]f32{32, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event, .Play_Sound_Event}, delta_time_in_music_ticks = 96*2}) // 2
	e20_h := ha_add(&gmem.entities, Entity { pos = [2]f32{34, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event, }, delta_time_in_music_ticks = 96*2}) // 4


	e21_h := ha_add(&gmem.entities, Entity { pos = [2]f32{38, 6}, sprite_data = .Unicycle1,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2}) // 2
	e22_h := ha_add(&gmem.entities, Entity { pos = [2]f32{40, 6}, sprite_data = .Unicycle1,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96}) // 4
	e23_h := ha_add(&gmem.entities, Entity { pos = [2]f32{42, 6}, sprite_data = .Unicycle1,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96})

	e30_h := ha_add(&gmem.entities, Entity { pos = [2]f32{44, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2})
	e31_h := ha_add(&gmem.entities, Entity { pos = [2]f32{46, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2})
	e32_h := ha_add(&gmem.entities, Entity { pos = [2]f32{48, 4}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2})
	e34_h := ha_add(&gmem.entities, Entity { pos = [2]f32{48, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2})
	e35_h := ha_add(&gmem.entities, Entity { pos = [2]f32{50, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2})
	e36_h := ha_add(&gmem.entities, Entity { pos = [2]f32{52, 6}, sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2})


	biscuit_h = ha_add(&gmem.entities, Entity { parent_entity_handle = e1_h, pos = [2]f32{0,0}, sprite_data =.Regular_Biscuit, behaviors = { .Is_Biscuit }, collider = rl.Rectangle { 0.33, 0.33, 0.33, 0.33} })
	set_parent(biscuit_h, e1_h)
	gmem.first_biscuit_parent_h = e1_h

	pass_ring := [?]Entity_Handle{e1_h, e2_h, e3_h, e4_h, e6_h, e7_h, e10_h, e12_h, e13_h, e14_h, e16_h, e17_h, e18_h, e19_h, e20_h,
		e21_h, e22_h, e23_h,
		e30_h, e31_h, e32_h, e34_h, e35_h, e36_h,
	 }
	
	create_entity_ring(pass_ring[:])

}


create_level_3 :: proc()
{
	rl.UnloadMusicStream(gmem.music)
    gmem.music = rl.LoadMusicStream("./assets/monkey_with_snare_success.mp3")
    gmem.music_bpm = 160.0

	rl.StopMusicStream(gmem.music)
	rl.PlayMusicStream(gmem.music)

	ha_clear(&gmem.entities)

	start_cursor := [2]f32{2,6}
	cursor := start_cursor

	start_handle, end_handle : Entity_Handle
	cursor, start_handle, end_handle = create_entities_with_cursor_and_set_next(cursor, Entity_Handle{}, [2]f32{2,0}, 
			 Entity { sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96,},
			 Entity { sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2},
			 Entity { sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2},
			 Entity { sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2},
			 Entity { sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event, .Play_Sound_Event}, delta_time_in_music_ticks = 96*2 },
			 Entity { sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2},
		)

	cursor.x += 2
	cursor, _, end_handle = create_entities_with_cursor_and_set_next(cursor, end_handle, [2]f32{2, 0}, 
			Entity { sprite_data = .Unicycle1, behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2 },
			Entity { sprite_data = .Unicycle1, behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96 },
			Entity { sprite_data = .Unicycle1, behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96 },
		)
	cursor.x += 2

	cursor, _, end_handle = create_entities_with_cursor_and_set_next(cursor, end_handle, [2]f32{2,0}, 
			 Entity { sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2,},
			 Entity { sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2},
			 Entity { sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2},
			 Entity { sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2},
			 Entity { sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event, .Play_Sound_Event}, delta_time_in_music_ticks = 96*2 },
			 Entity { sprite_data = .Person,  behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2},
		)

	cursor.x += 2
	cursor, _, end_handle = create_entities_with_cursor_and_set_next(cursor, end_handle, [2]f32{2, 0}, 
			Entity { sprite_data = .Unicycle1, behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96*2 },
			Entity { sprite_data = .Unicycle1, behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96 },
			Entity { sprite_data = .Unicycle1, behaviors = {.Face_Biscuit, .Music_Event}, delta_time_in_music_ticks = 96 },
		)
	cursor.x += 2

	// Note(jblat): I dont think this _needs_ to be a ring since the song won't be looping anymore
	set_next_entity(end_handle, start_handle) // make ring

	// we keep external handle of biscuit cause right now we only have 1
	// so now we don't have to go hunting for it in the entity array
	// whenever we need it
	biscuit_h = ha_add(&gmem.entities, Entity { parent_entity_handle = start_handle, pos = [2]f32{0,0}, sprite_data =.Regular_Biscuit, behaviors = { .Is_Biscuit }, collider = rl.Rectangle { 0.33, 0.33, 0.33, 0.33} })
	set_parent(biscuit_h, start_handle)

	// This just sets the head of the linked list
	gmem.first_biscuit_parent_h = start_handle

}

create_level_4 :: proc()
{
	rl.UnloadMusicStream(gmem.music)
    gmem.music = rl.LoadMusicStream("./assets/festive-biscuit_full.mp3")
    gmem.music_bpm = 132.0
}

// GAMEPLAY 


pass_biscuit :: proc(biscuit_handle : Entity_Handle)
{
	biscuit := ha_get_ptr(gmem.entities, biscuit_handle)
	biscuit_root_pos := entity_get_root_pos(biscuit_handle)
	parent := ha_get_ptr(gmem.entities, biscuit.parent_entity_handle)
	if parent == nil do return // gtfo

	next_parent_handle := parent.next_entity_handle
	biscuit.parent_entity_handle = next_parent_handle
	biscuit.pos = entity_root_pos_to_relative_pos(biscuit_root_pos, biscuit.parent_entity_handle)

	ms := rhythm_get_ms_from_ticks(96/2, 160.0) // eight note
	sec := f32(ms) / 1000.0

	lerp_position_start(&biscuit.lerp_pos, sec, biscuit.pos, [2]f32{0,0})
}


rhythm_get_ticks_from_ms :: proc(ms : u64, bpm : f32) -> u64
{
	ticks_per_quarter_note :: 96

	quarter_note_ms := 60000.0 / bpm
    ticks_per_ms := f32(ticks_per_quarter_note) / quarter_note_ms

    ticks := u64(f32(ms) * ticks_per_ms)
    
    return ticks
}

rhythm_get_ms_from_ticks :: proc(ticks : u64, bpm : f32) -> u64
{
 	ticks_per_quarter_note :: 96

    quarter_note_ms := 60000.0 / bpm
    ms_per_tick := quarter_note_ms / f32(ticks_per_quarter_note)

    ms := u64(f32(ticks) * ms_per_tick)
    return ms
}

// API


@(export)
game_memory_size :: proc() -> int 
{
    return size_of(gmem)
}


@(export)
game_memory_ptr :: proc() -> rawptr 
{
    return gmem
}


@(export)
game_hot_reload :: proc(mem : rawptr) 
{
    gmem = (^Game_Memory)(mem)
    create_level_3()
}


@(export)
game_is_build_requested :: proc() -> bool 
{
    yes := rl.IsKeyPressed(.F5)
    if yes 
    {
        return true
    }
    return false
}


@(export)
game_should_run :: proc() -> bool 
{
    no := rl.WindowShouldClose()
    if no 
    {
        return false
    }
    return true
}


@(export)
game_free_memory :: proc() 
{
    free(gmem)
    rl.UnloadRenderTexture(gmem.game_render_target)
}


@(export)
game_init_platform :: proc() 
{
    default_window_width : i32 = 1280
    default_window_height : i32 = 720

    window_width : i32 = default_window_width
    window_height : i32 = default_window_height
    window_pos_x : i32 = 0
    window_pos_y : i32 = 50

    window_save_data := Window_Save_Data{}

    // bytes_window_save_data, err := os2.read_entire_file_from_path(global_filename_window_save_data, context.temp_allocator)
    bytes_window_save_data, ok := read_entire_file(global_filename_window_save_data, context.temp_allocator)

    if ok == false 
    {
        fmt.printfln("Error reading from window save data file: %v", ok)
    }
     else 
    {
        mem.copy(&window_save_data, &bytes_window_save_data[0], size_of(window_save_data))

        window_width = window_save_data.width
        window_height = window_save_data.height
        window_pos_x = window_save_data.x
        window_pos_y = window_save_data.y
    }

    rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
    rl.InitWindow(window_width, window_height, "Biscuit Boy")
    rl.SetWindowPosition(window_pos_x, window_pos_y)

    after_set_pos_monitor_id := rl.GetCurrentMonitor()
    after_set_pos_monitor_pos := rl.GetMonitorPosition(after_set_pos_monitor_id)
    after_set_pos_monitor_width := rl.GetMonitorWidth(after_set_pos_monitor_id)
    after_set_pos_monitor_height := rl.GetMonitorHeight(after_set_pos_monitor_id)

    is_window_out_of_monitor_bounds :=
        f32(window_pos_x) < after_set_pos_monitor_pos.x ||
        f32(window_pos_y) < after_set_pos_monitor_pos.y ||
        window_pos_x > after_set_pos_monitor_width ||
        window_pos_y > after_set_pos_monitor_height

    if is_window_out_of_monitor_bounds 
    {
        reset_window_pos_x := i32(after_set_pos_monitor_pos.x)
        reset_window_pos_y := i32(after_set_pos_monitor_pos.y) + 40
        reset_window_width := default_window_width
        reset_window_height := default_window_height

        rl.SetWindowPosition(reset_window_pos_x, reset_window_pos_y)
        rl.SetWindowSize(reset_window_width, reset_window_height)
    }
    biscuit_image := rl.LoadImage("./assets/giant-biscuit.png")
    rl.SetWindowIcon(biscuit_image)
    rl.InitAudioDevice()
    rl.SetTargetFPS(60)
}


@(export)
game_init :: proc() 
{

    gmem = new(Game_Memory)

    gmem.root_state = .Main_Menu

    game_render_target := rl.LoadRenderTexture(i32(global_game_view_pixels_width), i32(global_game_view_pixels_height))
    rl.SetTextureFilter(game_render_target.texture, rl.TextureFilter.POINT)
    rl.SetTextureWrap(game_render_target.texture, .CLAMP) // this stops sub-pixel artifacts on edges of game texture

    gmem.game_render_target = game_render_target

    gmem.dbg_show_grid = false
    gmem.dbg_is_frogger_unkillable = false

    gmem.font = rl.LoadFontFromMemory(".otf", &bytes_font_data[0], i32(len(bytes_font_data)), 256, nil, 0)

    gmem.dbg_camera_zoom = 1.0

    gmem.dbg_speed_multiplier = 1.0

    gmem.rectangle = rl.Rectangle{0, 0, 1, 1}
    gmem.rectangle_color = rl.GREEN

    texture_bytes_png_map_to_load := #partial [Texture_Id][]byte {
    	.Giant_Biscuit = bytes_png_giant_biscuit[:],
    	.Person = bytes_png_person[:],
    	.Regular_Biscuit = bytes_png_regular_biscuit[:],
    	.Cannon = bytes_png_cannon[:],
    	.Unicycle1 = bytes_png_unicycle1[:],
    	.Rope_Ladder = bytes_png_rope[:],
    	.Shark = bytes_png_shark[:],
    	.Georgie = bytes_png_georgie[:],
    	.Reticle = bytes_png_reticle[:],
    	.Bumper_Circus = bytes_png_bumper_circus[:],
    	.Bumper_Unicycle = bytes_png_bumper_unicycle[:],
    	.Statuses_Sprite_Sheet = bytes_png_statuses[:],
    	.Spacebar_Sprite_Sheet = bytes_png_spacebar_spritesheet[:],
    	.Play_Button_Spritesheet = bytes_png_play_button_spritesheet[:],
    	.Back_Button_Spritesheet = bytes_png_back_button_spritesheet[:],
    	.Credits_Button_Spritesheet = bytes_png_credits_button_spritesheet[:],
    	.Credits = bytes_png_credits[:],
    	.Menu_Bg = bytes_png_menu_bg[:],
    	.Framing_Decoration = bytes_png_framing_decorations[:],

    }

    for bytes, tex_id in texture_bytes_png_map_to_load
    {
    	if tex_id == .None do continue
    	img := rl.LoadImageFromMemory(".png", &bytes[0], i32(len(bytes)))
    	gmem.textures[tex_id] = rl.LoadTextureFromImage(img)
    	rl.UnloadImage(img)
    }

    gmem.overlay_image = rl.GenImageColor(5, 5, rl.BLANK)
    gmem.overlay_tex = rl.LoadTextureFromImage(gmem.overlay_image)


    gmem.clap_sound = rl.LoadSound("./assets/clap.wav")
    gmem.ready_sound = rl.LoadSound("./assets/ready.wav")
    rl.SetSoundVolume(gmem.ready_sound, 6.0)

    gmem.bumper_voice = rl.LoadSound("./assets/bumper_circus.wav")
    gmem.bumper_sparkle_sound = rl.LoadSound("./assets/success_1.mp3")

    gmem.pop_sound = rl.LoadSound("./assets/ui_select.mp3")

    // create_level_3()

    root_state_main_menu_enter()

}



root_state_game :: proc() 
{
	biscuit_in_bounds_region := rl.Rectangle { 0, 0, 100, 30}


	length_of_track := rl.GetMusicTimeLength(gmem.music)
	current_time_in_track := rl.GetMusicTimePlayed(gmem.music)
	
	music_is_over := current_time_in_track + 0.3 >= length_of_track // added additional time here because raylib will want to loop the song and im not quite sure if there a way to tell if the song just finised...
	
	if music_is_over
	{
		// handle this case better
		gmem.track_time_ms_previous = 0
		create_level_3()
	}

    if rl.IsKeyPressed(.ENTER) 
    {
        gmem.pause = !gmem.pause
    }

    if rl.IsKeyPressed(.R)
    {
    	// reset
    	// rl.StopMusicStream(gmem.music)
    	gmem.track_time_ms_previous = 0
    	create_level_3()
    	// rl.PlayMusicStream(gmem.music)
    }

    skip_next_frame := false

    when ODIN_DEBUG 
    {
        if rl.IsKeyPressed(.M) 
        {
            root_state_main_menu_enter()
            return
        }


        if rl.IsKeyDown(.A) && rl.IsKeyDown(.D) 
        {
            gmem.dbg_camera_offset = 0
        }
         else if rl.IsKeyPressed(.A) 
        {
            gmem.dbg_camera_offset.x += global_game_texture_grid_cell_size
        }
         else if rl.IsKeyPressed(.D) 
        {
            gmem.dbg_camera_offset.x -= global_game_texture_grid_cell_size
        }
         else if rl.IsKeyPressed(.S) 
        {
            gmem.dbg_camera_offset.y -= global_game_texture_grid_cell_size
        }
         else if rl.IsKeyPressed(.W) 
        {
            gmem.dbg_camera_offset.y += global_game_texture_grid_cell_size
        }

        if rl.IsKeyDown(.MINUS) && rl.IsKeyDown(.EQUAL) 
        {
            gmem.dbg_camera_zoom = 1.0
        }
         else if rl.IsKeyPressed(.MINUS) 
        {
            gmem.dbg_camera_zoom -= 0.1
            gmem.dbg_camera_zoom = max(gmem.dbg_camera_zoom, 0.1)
        }
         else if rl.IsKeyPressed(.EQUAL) 
        {
            gmem.dbg_camera_zoom += 0.1
        }

        skip_next_frame = rl.IsKeyPressed(.RIGHT)

        if rl.IsKeyDown(.LEFT_BRACKET) && rl.IsKeyDown(.RIGHT_BRACKET) 
        {
            gmem.dbg_speed_multiplier = 5.0
        }
         else if rl.IsKeyDown(.LEFT_BRACKET) 
        {
            gmem.dbg_speed_multiplier = 2.0
        }
         else if rl.IsKeyDown(.RIGHT_BRACKET) 
        {
            gmem.dbg_speed_multiplier = 3.0
        }
         else 
        {
            gmem.dbg_speed_multiplier = 1.0
        }

    }


    frame_time_uncapped := rl.GetFrameTime()
    frame_time := min(frame_time_uncapped, f32(1.0 / 60.0))


    should_run_simulation := true
    if gmem.pause && !skip_next_frame 
    {
        should_run_simulation = false
    }

    if should_run_simulation 
    {
		rl.UpdateMusicStream(gmem.music)


        scale := min(f32(rl.GetScreenWidth()) / global_game_view_pixels_width, f32(rl.GetScreenHeight()) / global_game_view_pixels_height)

        // Update virtual mouse (clamped mouse value behind game screen)
        mouse := rl.GetMousePosition()
        virtual_mouse_current := [2]f32{0, 0}
        virtual_mouse_current.x = (mouse.x - (f32(rl.GetScreenWidth()) - (global_game_view_pixels_width * scale)) * 0.5) / scale
        virtual_mouse_current.y = (mouse.y - (f32(rl.GetScreenHeight()) - (global_game_view_pixels_height * scale)) * 0.5) / scale
        virtual_mouse_current = rl.Vector2Clamp(virtual_mouse_current, [2]f32{0, 0}, [2]f32{global_game_view_pixels_width, global_game_view_pixels_height})
        virtual_mouse_current -= gmem.camera.offset
        virtual_mouse_current += gmem.camera.target
        virtual_mouse_current.x /= gmem.camera.zoom
        virtual_mouse_current.y /= gmem.camera.zoom
        grid_mouse := [2]f32{virtual_mouse_current.x / global_game_texture_grid_cell_size, virtual_mouse_current.y / global_game_texture_grid_cell_size}

        { 
        	// paint on the overlay
        	overlay_rectangle := rl.Rectangle{0, 0, 1920, 1080}
        	is_paint_cursor_on_image := rl.CheckCollisionPointRec(virtual_mouse_current, overlay_rectangle)
        	if is_paint_cursor_on_image
        	{
        		if rl.IsMouseButtonDown(.LEFT)
        		{
        			rl.ImageDrawLine(&gmem.overlay_image, i32(gmem.virtual_mouse_previous.x), i32(gmem.virtual_mouse_previous.y) , i32(virtual_mouse_current.x), i32(virtual_mouse_current.y), rl.BLACK)
        			rl.UpdateTexture(gmem.overlay_tex, gmem.overlay_image.data)
        		}
        		else if rl.IsMouseButtonDown(.RIGHT)
        		{
        			rl.ImageDrawPixel(&gmem.overlay_image, i32(virtual_mouse_current.x), i32(virtual_mouse_current.y), rl.BLANK)
        			rl.UpdateTexture(gmem.overlay_tex, gmem.overlay_image.data)
        		}
        }

        gmem.virtual_mouse_previous = virtual_mouse_current

        }

        // if rl.IsMouseButtonPressed(.LEFT) 
        // {
        //     lerp_position_start(&gmem.rectangle_lerp_position, 0.15, [2]f32{gmem.rectangle.x, gmem.rectangle.y}, grid_mouse)
        // }

        if gmem.rectangle_lerp_position.timer.t < gmem.rectangle_lerp_position.timer.duration 
        {
            new_pos := lerp_position_advance(&gmem.rectangle_lerp_position, frame_time)
            gmem.rectangle.x = new_pos.x
            gmem.rectangle.y = new_pos.y
        }

       	biscuit_id := entity_find_first_matching_behavior({.Is_Biscuit})

   		biscuit := ha_get_ptr(gmem.entities, biscuit_h)
   		biscuit_parent, _ := ha_get(gmem.entities, biscuit.parent_entity_handle)

   		can_manually_pass_biscuit := rl.IsKeyPressed(.H) && biscuit.lerp_pos.timer.t >= biscuit.lerp_pos.timer.duration && !(.Auto_Pass in biscuit_parent.behaviors)
       	if can_manually_pass_biscuit
       	{
       		if !(.Shoot_In_Direction in biscuit_parent.behaviors)
       		{
	       		pass_biscuit(biscuit_id)
       		}
       	}

       	if biscuit.lerp_pos.timer.t < biscuit.lerp_pos.timer.duration
       	{
       		new_pos, just_finished := lerp_position_advance_and_notify_just_finished(&biscuit.lerp_pos, frame_time)
       		biscuit.pos = new_pos
       		if just_finished
       		{
       			// TODO(jblat) : yuck
       			parent_ptr := ha_get_ptr(gmem.entities, biscuit.parent_entity_handle)
       			if .Auto_Pass in parent_ptr.behaviors
       			{
					parent_ptr.wait_timer = parent_ptr.wait_timer_duration       				
       			}
       		}
       	}

       	{ // biscuit collides with things
       		entity_iter := ha_make_iter(gmem.entities)
       		for entity, handle in ha_iter(&entity_iter)
       		{
       			if handle == biscuit_h do continue
       			if .Hazard in entity.behaviors
       			{
   					biscuit_root_collider := entity_get_root_collider(biscuit_id)
   					hazard_root_collider := entity_get_root_collider(handle)
       				is_biscuit_colliding_with_hazard := rl.CheckCollisionRecs(biscuit_root_collider, hazard_root_collider)
       				if is_biscuit_colliding_with_hazard
       				{
       					biscuit_root_pos := entity_get_root_pos(biscuit_id)
       					// Note(jblat): This aint good, this just some way to represent that a hazard got in the way of the biscuit
       					biscuit_relative_to_return_parent := entity_root_pos_to_relative_pos(biscuit_root_pos, entity.next_entity_handle)
       					biscuit.parent_entity_handle = entity.next_entity_handle
       					biscuit.pos = [2]f32{0,0}
       					biscuit.lerp_pos.timer.t = biscuit.lerp_pos.timer.duration      				
   					}
       			}
       		}
       	}

       	{ // general behvaior updates
       		entity_iter := ha_make_iter(gmem.entities)
       		for entity, handle in ha_iter(&entity_iter)
       		{
       			entity_ptr := ha_get_ptr(gmem.entities, handle)
       			if .Move_Veritcally_On_Parent in entity.behaviors
       			{
   					min_y : f32 = 0
   					parent_entity, _ := ha_get(gmem.entities, entity.parent_entity_handle)
   					max_y := parent_entity.veritcal_move_bounds

   					if entity.pos.y >= max_y
   					{
   						entity_ptr.vel.y = -entity.speed
   					}
   					else if entity.pos.y <= min_y
   					{
   						entity_ptr.vel.y = entity.speed
   					}
       			}
       			if .Moveable in entity.behaviors
       			{
       				// set this here so that only below if an biscuit is on the entity will it set the velocity
       				entity_ptr.vel = 0
       			}
       			if .Orbiting_Around_Parent in entity.behaviors
       			{
       				entity_ptr.orbiting_angle += f32(entity.orbiting_dir) * entity.speed * frame_time

       				entity_ptr.orbiting_angle = math.mod(entity_ptr.orbiting_angle, math.TAU)

       				entity_ptr.pos = [2]f32 {
       					math.cos(entity.orbiting_angle) * entity.orbiting_distance,
       					math.sin(entity.orbiting_angle) * entity.orbiting_distance,
       				}
       			}
       			if .Swing_Around_Parent in entity.behaviors
   				{
   					if entity_ptr.orbiting_dir > 0 && entity_ptr.orbiting_angle >= entity_ptr.swing_angle_end
   					{
   						entity_ptr.orbiting_dir = -(entity_ptr.orbiting_dir)
   					}
   					else if entity_ptr.orbiting_dir < 0 && entity_ptr.orbiting_angle <= entity_ptr.swing_angle_start
   					{
   						entity_ptr.orbiting_dir = -(entity_ptr.orbiting_dir)
   					}
   				}
       		}
       	}

   		{ // biscuit affecting parent. IOW: Biscuit will give the biscuit holder some ability
			biscuit, _ := ha_get(gmem.entities, biscuit_h)

			parent_ptr := ha_get_ptr(gmem.entities, biscuit.parent_entity_handle)

			if parent_ptr != nil
			{
				if .Auto_Pass in parent_ptr.behaviors
				{
					just_finished := countdown_and_notify_just_finished(&parent_ptr.wait_timer, frame_time)
					if just_finished
					{
						pass_biscuit(biscuit_h)
					}
				}

				if .Moveable in parent_ptr.behaviors
	   			{
	   				if rl.IsKeyDown(.LEFT)
	   				{
	   					parent_ptr.vel.x = -parent_ptr.speed
	   				}
	   				else if rl.IsKeyDown(.RIGHT)
	   				{
	   					parent_ptr.vel.x = parent_ptr.speed
	   				}
	   				else
	   				{
	   					parent_ptr.vel.x = 0
	   				}
	   			}

	   			if .Shoot_In_Direction in parent_ptr.behaviors
	   			{
   					biscuit_ptr := ha_get_ptr(gmem.entities, biscuit_h)

	   				// Note(jblat): This sucks. It's because the parent switches as soon as biscuit is tossed to next parent
	   				if biscuit_ptr.lerp_pos.timer.t >= biscuit_ptr.lerp_pos.timer.duration
	   				{
	   					if rl.IsKeyPressed(.SPACE)
	   					{
	   						root_biscuit_pos := entity_get_root_pos(biscuit_h)
	   						biscuit_ptr.parent_entity_handle = {}
	   						biscuit_ptr.pos = root_biscuit_pos
			   				biscuit_ptr.lerp_pos.timer.t = biscuit_ptr.lerp_pos.timer.duration
			   				biscuit_ptr.vel = [2]f32{
			   					-math.cos(parent_ptr.aim_angle),
			   					math.sin(parent_ptr.aim_angle)
			   				}
			   				biscuit_ptr.vel *= 3
	   					}
	   				}
	   			}
			}
				
       	}

       	{ // music timing stuff
       		track_time_ms_current := u64(rl.GetMusicTimePlayed(gmem.music) * 1000)

       		track_time_ticks_current := rhythm_get_ticks_from_ms(track_time_ms_current, 160.0)
       		track_time_tick_previous := rhythm_get_ticks_from_ms(gmem.track_time_ms_previous, 160.0)

       		// needs to change
       		entity_current, _ := ha_get(gmem.entities, gmem.first_biscuit_parent_h)
       		entity_track_time_ticks : u64 = 0

       		for entity_current.next_entity_handle != gmem.first_biscuit_parent_h && entity_current.next_entity_handle != {}
       		{
       			entity_track_time_ticks += entity_current.delta_time_in_music_ticks

       			if .Music_Event in entity_current.behaviors
       			{
       				is_entity_current_within_trigger_window := false

   					if track_time_tick_previous <= track_time_ticks_current
   					{
   						is_entity_current_within_trigger_window = entity_track_time_ticks >= track_time_tick_previous && entity_track_time_ticks < track_time_ticks_current		
   					}
   					else
   					{
   				    	is_entity_current_within_trigger_window = entity_track_time_ticks >= track_time_tick_previous || entity_track_time_ticks < track_time_ticks_current
   					}

   					if is_entity_current_within_trigger_window
   					{
   						rl.PlaySound(gmem.clap_sound)
   						if .Play_Sound_Event in entity_current.behaviors
   						{
   							rl.PlaySound(gmem.ready_sound)
   						}
   						// NOTE(jblat): we may want to ensure we set the parent to the current entity here
   						// as otherwise there's nothing guaranteeing the biscuit is on the current musical entity
   						// it could be on any entity
   						pass_biscuit(biscuit_h)
   					}
       			}

       			entity_current, _ = ha_get(gmem.entities, entity_current.next_entity_handle)

       		}

       		gmem.track_time_ms_previous = track_time_ms_current
       	}

       	{ // check for musical hits on input

       		/**
       		 *                     current track time
       		 *        early_hit_window     |            late hit window
       		 * 				|              |             |
       		 		-----------------------------------------------
       		 *          e             e          |               e
       		 *          |             |          |               |
       		 *   entity track time    |          |               |
       		 *    will miss if        |       hit time           |
       		 *    not hit yet         |                    future entity track time
       		 *                        |                    outside of window
       		 *                   within hit window
       		 */

       		track_time_ms_current := u64(rl.GetMusicTimePlayed(gmem.music) * 1000)

       		early_timing_window_ms_i := i32(track_time_ms_current) - i32(sec_to_ms(frame_time) * 5) // roughly 10 frames
       		early_timing_window_ms_i = max(early_timing_window_ms_i, 0)
       		early_timing_window_ms := u64(early_timing_window_ms_i)
       		late_timing_window_ms := track_time_ms_current + u64(sec_to_ms(frame_time) * 5) // roughly 10 frames

       		entity_current, _ := ha_get(gmem.entities, gmem.first_biscuit_parent_h)
       		entity_track_time_ms : u64 = 0

       		did_user_attempt_hit_this_frame := rl.IsKeyPressed(.SPACE)


       		/**
       		 * Loop looks like 
       		 * 
       		 *  entity.next -> entity.next -> entity.next -> entity.next -> ...
       		 * 
       		 */
       		for entity_current.next_entity_handle != gmem.first_biscuit_parent_h && entity_current.next_entity_handle != {}
       		{
       			entity_track_time_ms += rhythm_get_ms_from_ticks(entity_current.delta_time_in_music_ticks, 160.0)

       			is_entity_after_hit_window := late_timing_window_ms < entity_track_time_ms 
       			if is_entity_after_hit_window
       			{
       				/**   early hit window
       				 *     |        
       				 *     |           
       				 *     |       late hit window
       				 *     |           |
       				 * ----------------------e--------------
       				 *                       |
       				 *                 current entity
       				 *                 ^^^^ in future so just get out
       				 */
       				break
       			}

       			if .Music_Event in entity_current.behaviors
       			{
       				is_entity_current_within_hit_window := early_timing_window_ms <= entity_track_time_ms && entity_track_time_ms <= late_timing_window_ms

   					is_entity_already_missed_or_hit := entity_current.status == .Hit || entity_current.status == .Missed

   					should_hit_entity := is_entity_current_within_hit_window && !is_entity_already_missed_or_hit && did_user_attempt_hit_this_frame

   					if should_hit_entity
   					{
   						entity_current_ptr := ha_get_ptr(gmem.entities, entity_current.handle)
   						entity_current_ptr.status = .Hit
   						status_entity := Entity {parent_entity_handle = entity_current.handle, pos = [2]f32{0, -1}, sprite_data = .Status_Hit}
   						create_entity(status_entity)
   					}

   					did_user_miss_entity := entity_track_time_ms < early_timing_window_ms && !is_entity_already_missed_or_hit
   					
   					if did_user_miss_entity 
   					{
   						entity_current_ptr := ha_get_ptr(gmem.entities, entity_current.handle)
   						entity_current_ptr.status = .Missed
   						status_entity := Entity { parent_entity_handle = entity_current.handle, pos = [2]f32{0, -1}, sprite_data = .Status_Miss }
   						create_entity(status_entity)
   					}
       			}

       			entity_current, _ = ha_get(gmem.entities, entity_current.next_entity_handle)
       		}
       	}

       	{ // moving
       		entity_iter := ha_make_iter(gmem.entities)
       		for entity, handle in ha_iter(&entity_iter)
       		{
       			entity_ptr := ha_get_ptr(gmem.entities, handle)
       			entity_ptr.pos += entity_ptr.vel * frame_time
       		}

       		biscuit_ptr := ha_get_ptr(gmem.entities, biscuit_h)
       		biscuit_ptr.pos += biscuit.vel * frame_time
       	}

       	{ // biscuit out of bounds?
       		biscuit_root_collider := entity_get_root_collider(biscuit_h)
       		is_biscuit_in_bounds := rl.CheckCollisionRecs(biscuit_root_collider, biscuit_in_bounds_region)
       		if !is_biscuit_in_bounds
       		{ 
       			// just give it to someone
       			// doesn't matter who right now
       			biscuit.pos = [2]f32{0,0}
       			biscuit.vel = [2]f32{0,0}
       			entity_iter := ha_make_iter(gmem.entities)
       			for entity, handle in ha_iter(&entity_iter)
       			{
       				// just give it to the first person you find
       				if entity.sprite_data == .Person
       				{
						biscuit.parent_entity_handle = handle
						break
       				}
       			}
       		}
       	}
    }


    
    {     // debug options
        if rl.IsKeyPressed(.F1) 
        {
            gmem.dbg_show_grid = !gmem.dbg_show_grid
        }

        if rl.IsKeyPressed(.F2) 
        {
            gmem.dbg_is_frogger_unkillable = !gmem.dbg_is_frogger_unkillable
        }

        if rl.IsKeyPressed(.F3) 
        {
            gmem.dbg_show_entity_bounding_rectangles = !gmem.dbg_show_entity_bounding_rectangles
        }

        if rl.IsKeyPressed(.F4) 
        {
            gmem.dbg_show_level = !gmem.dbg_show_level
        }

    }

    
    {  // DRAW TO RENDER TEXTURE


        gmem.camera.offset = gmem.dbg_camera_offset
        gmem.camera.offset.x += global_game_view_pixels_width/2
        gmem.camera.offset.y += global_game_view_pixels_height/2
        gmem.camera.zoom = gmem.dbg_camera_zoom


		biscuit_root_pos := entity_get_root_pos(biscuit_h)
		biscuit_root_pos += 0.5
		actual_pos := rlgrid.get_actual_pos(biscuit_root_pos, 32)
		gmem.camera.target = actual_pos 
        	
        
        rl.BeginTextureMode(gmem.game_render_target)

        rl.BeginMode2D(gmem.camera)

        rl.ClearBackground(rl.LIGHTGRAY)

        rl.DrawTexture(gmem.overlay_tex, 0,0,rl.WHITE)


        
        {
            rlgrid.draw_rectangle_on_grid_justified(gmem.rectangle, gmem.rectangle_color, global_game_texture_grid_cell_size, .Centered, .Centered)
        }

        {
        	entity_iter := ha_make_iter(gmem.entities)
        	for entity, handle in ha_iter(&entity_iter)
        	{
        		
        		root_pos := entity_get_root_pos(handle)

        		

        		biscuit_root_pos := entity_get_root_pos(biscuit_h)
        		biscuit_is_to_left_of_this_entity := biscuit_root_pos.x < root_pos.x
        		biscuit_is_to_right_of_this_entity := biscuit_root_pos.x > root_pos.x

        		flip_x := false

        		if .Face_Biscuit in entity.behaviors
        		{
	        		if biscuit_is_to_right_of_this_entity
	        		{
	        			flip_x = true
	        		}        			
        		}

        		flip_y := false
        		if .Flip_V in entity.behaviors
        		{
        			if entity.vel.y > 0
        			{
        				flip_y = true
        			}
        		}

        		switch sd in entity.sprite_data
        		{
        			case Texture_Id:
        			{
        				tex_id := sd

        				tex := gmem.textures[tex_id]

        				tex_width_f := f32(tex.width)
        				tex_height_f := f32(tex.height)
        				src := rl.Rectangle {0,0, 1, 1} // TODO: This will only work for single tile sprites
        				dst := rl.Rectangle {root_pos.x, root_pos.y, 1, 1}

        				rlgrid.draw_grid_texture_clip_on_grid(tex, src, 32, dst, 32, 0, flip_x = flip_x, flip_y = flip_y)

        			}
        			case Sprite_Clip_Name:
        			{
        				sprite_clip_name := sd

        				draw_sprite_sheet_clip_on_game_texture_grid(sprite_clip_name,  root_pos)
        			}
        		}


        		if .Auto_Pass in entity.behaviors
        		{
        			p := entity.wait_timer / entity.wait_timer_duration
        			r := rl.Rectangle{entity.pos.x, entity.pos.y + 1, 1* p, 1}
        			color := rl.GREEN
        			if p < 0.25
        			{
        				color = rl.RED
        			}
        			rlgrid.draw_rectangle_on_grid(r, color, 32)
        		}

        		if .Shoot_In_Direction in entity.behaviors
        		{
        			root_entity_pos := entity_get_root_pos(handle)
 					// assuming entity takes up one tile
 					root_entity_pos_centered := root_entity_pos + 0.5

 					visual_shoot_length : f32 = 2.0
 					end_pos := [2]f32 { 
 						root_entity_pos_centered.x + math.cos(entity.aim_angle) * visual_shoot_length,
 						root_entity_pos_centered.y + math.sin(entity.aim_angle) * visual_shoot_length 
 					}

 					reticle_tex := gmem.textures[.Reticle]
 					ret_tex_grid_width := f32(reticle_tex.width)/32
 					ret_tex_grid_height := f32(reticle_tex.height)/32
 					src := rl.Rectangle { 0, 0, f32(reticle_tex.width)/32, f32(reticle_tex.height)/32}
 					dst := rl.Rectangle { end_pos.x - ret_tex_grid_width/2, end_pos.y - ret_tex_grid_height/2, f32(reticle_tex.width)/32, f32(reticle_tex.height)/32}
 					rlgrid.draw_grid_texture_clip_on_grid(reticle_tex, src, 32, dst, 32, 0 )
        		}
        	}
        }

        
        if gmem.dbg_show_grid && gmem.dbg_camera_zoom > 0.09 
        {

            // 1) Convert all 4 screen corners to world space (handles offset, zoom, rotation).
            render_width := f32(gmem.game_render_target.texture.width)
            render_height := f32(gmem.game_render_target.texture.height)

            // Convert all 4 render texture corners to world space
            rc := [4][2]f32{{0, 0}, {render_width, 0}, {0, render_height}, {render_width, render_height}}

            wc := [4][2]f32{rl.GetScreenToWorld2D(rc[0], gmem.camera), rl.GetScreenToWorld2D(rc[1], gmem.camera), rl.GetScreenToWorld2D(rc[2], gmem.camera), rl.GetScreenToWorld2D(rc[3], gmem.camera)}

            minX : f32 = wc[0].x
            maxX : f32 = wc[0].x
            minY : f32 = wc[0].y
            maxY : f32 = wc[0].y
            for i := 1; i < 4; i += 1 
            {
                if wc[i].x < minX do minX = wc[i].x
                if wc[i].x > maxX do maxX = wc[i].x
                if wc[i].y < minY do minY = wc[i].y
                if wc[i].y > maxY do maxY = wc[i].y
            }

            // 2) Snap the visible extent to grid lines.
            startX : f32 = math.floor(minX / global_game_texture_grid_cell_size) * global_game_texture_grid_cell_size
            endX : f32 = math.ceil(maxX / global_game_texture_grid_cell_size) * global_game_texture_grid_cell_size
            startY : f32 = math.floor(minY / global_game_texture_grid_cell_size) * global_game_texture_grid_cell_size
            endY : f32 = math.ceil(maxY / global_game_texture_grid_cell_size) * global_game_texture_grid_cell_size

            // Optional: keep roughly 1px thickness regardless of zoom (since we're inside BeginMode2D)
            thickness : f32 = (gmem.camera.zoom > 0.0) ? (1.0 / gmem.camera.zoom) : 1.0

            // Optional: when zoomed way out, skip lines so spacing stays >= ~8px on screen
            minPixelSpacing : f32 = 8.0
            stepMul : int = int(math.ceil(minPixelSpacing) / (global_game_texture_grid_cell_size * (gmem.camera.zoom > 0 ? gmem.camera.zoom : 1.0)))
            if stepMul < 1 do stepMul = 1
            if stepMul > 100 do stepMul = 100

            step : f32 = global_game_texture_grid_cell_size * f32(stepMul)

            // 3) Draw vertical lines.
            for x : f32 = startX; x <= endX; x += step 
            {
                rl.DrawLineEx([2]f32{x, startY}, [2]f32{x, endY}, thickness, rl.WHITE)
            }
            // 4) Draw horizontal lines.
            for y : f32 = startY; y <= endY; y += step 
            {
                rl.DrawLineEx([2]f32{startX, y}, [2]f32{endX, y}, thickness, rl.WHITE)
            }

            // 5) Emphasize world axes if they’re visible.
            if (minY <= 0 && maxY >= 0) 
            {
                rl.DrawLineEx([2]f32{startX, 0}, [2]f32{endX, 0}, thickness * 2.0, rl.GRAY)
            }
            if (minX <= 0 && maxX >= 0) 
            {
                rl.DrawLineEx([2]f32{0, startY}, [2]f32{0, endY}, thickness * 2.0, rl.GRAY)
            }


     		{
     			entity_iter := ha_make_iter(gmem.entities)
     			for entity, handle in ha_iter(&entity_iter)
     			{
     				if entity.veritcal_move_bounds > 0
     				{
     					r := rl.Rectangle { entity.pos.x, entity.pos.y, 1, entity.veritcal_move_bounds}
     					rlgrid.draw_rectangle_on_grid(r, rl.Color{255,0,0,50}, 32)
     				}
     				collider_r := entity_get_root_collider(handle)
     				rlgrid.draw_rectangle_on_grid(collider_r, rl.Color{0,0,255,50}, 32)
     				
     				if .Orbiting_Around_Parent in entity.behaviors
     				{
     					
     					red_alpha := rl.RED
     					red_alpha.a = 80
     					green_alpha := rl.GREEN
     					green_alpha.a = 80

     					root_parent_pos := entity_get_root_pos(entity.parent_entity_handle)
     					root_entity_pos := entity_get_root_pos(handle)

     					rlgrid.draw_circle_on_grid(root_parent_pos, entity.orbiting_distance, red_alpha, 32)
     					rlgrid.draw_arrow_on_grid(root_parent_pos, root_entity_pos, 0.1, green_alpha, 32)
     				}

     				if .Shoot_In_Direction in entity.behaviors
     				{
     					root_entity_pos := entity_get_root_pos(handle)
     					// assuming entity takes up one tile
     					root_entity_pos_centered := root_entity_pos + 0.5

     					visual_shoot_length : f32 = 2.0
     					end_pos := [2]f32 { 
     						root_entity_pos_centered.x + math.cos(entity.aim_angle) * visual_shoot_length,
     						root_entity_pos_centered.y + math.sin(entity.aim_angle) * visual_shoot_length 
     					}

     					rlgrid.draw_arrow_on_grid(root_entity_pos_centered, end_pos, 0.1, rl.GOLD, 32)
     				}
     			}

     			{ // draw in-bounds region
     				rlgrid.draw_rectangle_lines_on_grid(biscuit_in_bounds_region,0.1, rl.RED, 32 )
     			}
     		}


        }

        rl.EndMode2D()

        { // draw position of green rectangle anchor cursor
        	text_pos_of_rectangle_cursor := fmt.ctprintf("(%.2f, %.2f)", gmem.rectangle.x, gmem.rectangle.y)
            rlgrid.draw_text_on_grid(gmem.font, text_pos_of_rectangle_cursor, [2]f32{0,0}, 0.5, 0, rl.BLACK, global_game_texture_grid_cell_size)
        }

        { // draw spacebar picture
        	is_spacebar_down := rl.IsKeyDown(.SPACE)
        	if is_spacebar_down
        	{
        		draw_sprite_sheet_clip_on_game_texture_grid(.Spacebar_Down, [2]f32{8.75, 7.5})
        	}
        	else
        	{
        		draw_sprite_sheet_clip_on_game_texture_grid(.Spacebar_Up, [2]f32{8.75, 7.5})
        	}
        }

        { // draw decorations
        	rl.DrawTexture(gmem.textures[.Framing_Decoration], 0, 0, rl.WHITE)	
        }


        rl.EndTextureMode()
    }
}


root_state_main_menu_enter :: proc() 
{
	rl.UnloadMusicStream(gmem.music)
	gmem.music = rl.LoadMusicStream("./assets/biscuit.mp3")
	rl.PlayMusicStream(gmem.music)
    gmem.root_state = .Main_Menu
    gmem.main_menu_show_credits = false

}


root_state_main_menu :: proc() 
{
    @(static) visible : bool
    blink_timer_duration :: 0.3
    @(static) blink_timer : f32 = blink_timer_duration

    rl.UpdateMusicStream(gmem.music)

    scale := min(f32(rl.GetScreenWidth()) / global_game_view_pixels_width, f32(rl.GetScreenHeight()) / global_game_view_pixels_height)

    mouse := rl.GetMousePosition()
    virtual_mouse_current := [2]f32{0, 0}
    virtual_mouse_current.x = (mouse.x - (f32(rl.GetScreenWidth()) - (global_game_view_pixels_width * scale)) * 0.5) / scale
    virtual_mouse_current.y = (mouse.y - (f32(rl.GetScreenHeight()) - (global_game_view_pixels_height * scale)) * 0.5) / scale
    virtual_mouse_current = rl.Vector2Clamp(virtual_mouse_current, [2]f32{0, 0}, [2]f32{global_game_view_pixels_width, global_game_view_pixels_height})

    if rl.IsKeyPressed(.FIVE) // just some random hotkey to break on debugger
    {
    	intrinsics.debug_trap()
    }

    dt := rl.GetFrameTime()

	is_any_hovered_current := false

    if !gmem.main_menu_show_credits
    {
    	if countdown_and_notify_just_finished(&blink_timer, dt) 
	    {
	        visible = !visible
	        blink_timer = blink_timer_duration
	    }

	    is_input_start :=
	        rl.IsKeyPressed(.ENTER) ||
	        rl.IsGamepadButtonPressed(0, .MIDDLE) ||
	        rl.IsGamepadButtonPressed(0, .MIDDLE_LEFT) ||
	        rl.IsGamepadButtonPressed(0, .MIDDLE_RIGHT) ||
	        rl.IsGamepadButtonPressed(0, .RIGHT_FACE_DOWN)

	    if is_input_start 
	    {
	    	root_state_bumper_enter()
	    }

	    play_button_pos := [2]f32{13, 5}
	    credits_button_pos := [2]f32{12, 7}
		play_button_sprite_clip := Sprite_Clip_Name.Play_Button_Up
		credits_button_sprite_clip := Sprite_Clip_Name.Credits_Button_Up


	    {
	    	play_button_collision_rectangle := global_sprite_clips[.Play_Button_Up].clip_rectangle
	    	play_button_collision_rectangle.x = play_button_pos.x
	    	play_button_collision_rectangle.y = play_button_pos.y

	    	play_button_grid_rectangle := rlgrid.get_rectangle_on_grid(play_button_collision_rectangle, 32)


	    	is_hover_over_play_button := rl.CheckCollisionPointRec(virtual_mouse_current, play_button_grid_rectangle)
	    	if is_hover_over_play_button
	    	{
	    		play_button_sprite_clip = .Play_Button_Down
	    		is_any_hovered_current = true

	    		if rl.IsMouseButtonPressed(.LEFT)
	    		{
	    			root_state_bumper_enter()
	    		}
	    	}
	    }

	    {
	    	credits_button_collision_rectangle := global_sprite_clips[.Credits_Button_Up].clip_rectangle
	    	credits_button_collision_rectangle.x = credits_button_pos.x
	    	credits_button_collision_rectangle.y = credits_button_pos.y

	    	credits_button_grid_rectangle := rlgrid.get_rectangle_on_grid(credits_button_collision_rectangle, 32)

	    	is_hover_over_credits_button := rl.CheckCollisionPointRec(virtual_mouse_current, credits_button_grid_rectangle)
	    	if is_hover_over_credits_button
	    	{
	    		credits_button_sprite_clip = .Credits_Button_Down
    			is_any_hovered_current = true


	    		if rl.IsMouseButtonPressed(.LEFT)
	    		{
	    			gmem.main_menu_show_credits = true
	    		}
	    	}
	    }


	    rl.BeginTextureMode(gmem.game_render_target)
	    defer rl.EndTextureMode()

	    rl.ClearBackground(rl.BLACK)

	    rl.DrawTexture(gmem.textures[.Menu_Bg], 0, 0, rl.WHITE)
	    draw_sprite_sheet_clip_on_game_texture_grid(play_button_sprite_clip, play_button_pos)
	    draw_sprite_sheet_clip_on_game_texture_grid(credits_button_sprite_clip, credits_button_pos)

	    if false 
	    { // can activate if u want with visible toggle
	        press_enter_centered_pos := [2]f32{global_number_grid_cells_axis_x / 2, 8}
	        rlgrid.draw_text_on_grid_centered(gmem.font, "press enter to play", press_enter_centered_pos, 0.7, 0, rl.WHITE, global_game_texture_grid_cell_size)
	    }
    }
    else
    { // credits

    	if rl.IsKeyPressed(.ENTER)
    	{
    		gmem.main_menu_show_credits = false
    	}

	    back_button_pos := [2]f32{15, 9}
		back_button_sprite_clip := Sprite_Clip_Name.Back_Button_Up


		{
	    	back_button_collision_rectangle := global_sprite_clips[.Back_Button_Up].clip_rectangle
	    	back_button_collision_rectangle.x = back_button_pos.x
	    	back_button_collision_rectangle.y = back_button_pos.y

	    	back_button_grid_rectangle := rlgrid.get_rectangle_on_grid(back_button_collision_rectangle, 32)

	    	is_hover_over_back_button := rl.CheckCollisionPointRec(virtual_mouse_current, back_button_grid_rectangle)
	    	if is_hover_over_back_button
	    	{
	    		back_button_sprite_clip = .Back_Button_Down
				is_any_hovered_current = true
	    		
	    		if rl.IsMouseButtonPressed(.LEFT)
	    		{
	    			gmem.main_menu_show_credits = false
	    		}
	    	}
	    }

    	tex := gmem.textures[.Credits]

    	rl.BeginTextureMode(gmem.game_render_target)
	    defer rl.EndTextureMode()
    	rl.DrawTextureV(tex, [2]f32{0,0},rl.WHITE)
	    draw_sprite_sheet_clip_on_game_texture_grid(back_button_sprite_clip, back_button_pos)
    }

    just_hovered_a_button := is_any_hovered_current && !gmem.main_menu_any_button_hovered_previous
	if just_hovered_a_button
	{	
		rl.PlaySound(gmem.pop_sound)
	}
	gmem.main_menu_any_button_hovered_previous = is_any_hovered_current


    

}



root_state_bumper :: proc()
{
	/**
	 * The progression of the bumper is like so:
	 * 1 fade in the bumper image
	 * 2 play voice clip
	 * 3 fade out
	 * 4 enter level
	 */

	does_user_want_to_skip_bumper := rl.IsKeyPressed(.ENTER)
	if does_user_want_to_skip_bumper
	{
		root_state_game_enter()
		return
	}

	timer_duration : f32 = 2.0

	frame_time_uncapped := rl.GetFrameTime()
    frame_time := min(frame_time_uncapped, f32(1.0 / 60.0))

	tint := rl.WHITE

	fade_in_just_finished := countdown_and_notify_just_finished(&gmem.bumper_fade_in_timer, frame_time)
	if fade_in_just_finished 
	{
		rl.PlaySound(gmem.bumper_voice)
		gmem.bumper_did_voice_start = true

	}
	else if countdown_is_playing(gmem.bumper_fade_in_timer)
	{
		p := 1 - (gmem.bumper_fade_in_timer / timer_duration)
		transparency_based_on_elapsed_time_in_timer := f32(tint.a) * p
		tint.a = u8(transparency_based_on_elapsed_time_in_timer)		
	}

	if gmem.bumper_did_voice_start
	{
		voice_finished := !rl.IsSoundPlaying(gmem.bumper_voice)
		if voice_finished
		{
			gmem.bumper_did_voice_start = false
			gmem.bumper_fade_out_timer = timer_duration
		}
	}

	fade_out_just_finished := countdown_and_notify_just_finished(&gmem.bumper_fade_out_timer, frame_time)
	if fade_out_just_finished
	{
		root_state_game_enter()
	}
	else if countdown_is_playing(gmem.bumper_fade_out_timer)
	{
		p := gmem.bumper_fade_out_timer / timer_duration
		transparency_based_on_elapsed_time_in_timer := f32(tint.a) * p
		tint.a = u8(transparency_based_on_elapsed_time_in_timer)		
	}

	if !fade_out_just_finished
	{
		rl.BeginTextureMode(gmem.game_render_target)
		rl.ClearBackground(rl.BLACK)
		tex := gmem.textures[.Bumper_Circus]
		rl.DrawTexturePro(tex, rl.Rectangle{0,0,f32(tex.width), f32(tex.height)}, rl.Rectangle{0,0,global_game_view_pixels_width, global_game_view_pixels_height},[2]f32{0,0}, 0, tint )
		rl.EndTextureMode()

	}

}


root_state_bumper_enter :: proc()
{
	gmem.root_state = .Bumper
	timer_duration : f32 = 2.0

	gmem.bumper_texture = .Bumper_Circus
	gmem.bumper_fade_in_timer = timer_duration
	gmem.bumper_fade_out_timer = 0
	rl.PlaySound(gmem.bumper_sparkle_sound)
	gmem.bumper_did_voice_start = false
	// TODO: set correct voice here depending on level transition

}

root_state_game_enter :: proc()
{
	gmem.root_state = .Game
	create_level_3()
}

@(export)
game_update :: proc() 
{
    switch gmem.root_state 
    {
	    case .Main_Menu:
	        root_state_main_menu()
	    case .Game:
	        root_state_game()
	    case .Bumper:
	    	root_state_bumper()
    }


    // rendering

    screen_width := f32(rl.GetScreenWidth())
    screen_height := f32(rl.GetScreenHeight())


    
    {     // DRAW TO WINDOW

        rl.BeginDrawing()

        rl.ClearBackground(rl.BLACK)

        src := rl.Rectangle{0, 0, f32(gmem.game_render_target.texture.width), f32(-gmem.game_render_target.texture.height)}

        scale := min(screen_width / global_game_view_pixels_width, screen_height / global_game_view_pixels_height)

        window_scaled_width := global_game_view_pixels_width * scale
        window_scaled_height := global_game_view_pixels_height * scale

        dst := rl.Rectangle{(screen_width - window_scaled_width) / 2, (screen_height - window_scaled_height) / 2, window_scaled_width, window_scaled_height}
        rl.DrawTexturePro(gmem.game_render_target.texture, src, dst, [2]f32{0, 0}, 0, rl.WHITE)

        rl.EndDrawing()

    }

    free_all(context.temp_allocator)
}

@(export)
game_shutdown :: proc() 
{
    when ODIN_OS != .JS 
    {     // no need to save this in web

        window_pos := rl.GetWindowPosition()
        screen_width := rl.GetScreenWidth()
        screen_height := rl.GetScreenHeight()

        window_save_data := Window_Save_Data{i32(window_pos.x), i32(window_pos.y), screen_width, screen_height}
        bytes_window_save_data := mem.ptr_to_bytes(&window_save_data)

        ok := write_entire_file(global_filename_window_save_data, bytes_window_save_data)
        if !ok 
        {
            fmt.printfln("Error opening/creating Window Save Data File")
        }
    }
}


should_run :: proc() -> bool 
{
    when ODIN_OS != .JS 
    {
        // Never run this proc in browser. It contains a 16 ms sleep on web!
        if rl.WindowShouldClose() 
        {
            return false
        }
    }

    return true
}


// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
parent_window_size_changed :: proc(w, h : int) 
{
    rl.SetWindowSize(c.int(w), c.int(h))
}
