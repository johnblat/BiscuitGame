package game

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
bytes_png_shark :=#load("../assets/shark2.png")


global_filename_window_save_data := "window_save_data.jam"
global_game_view_pixels_width : f32 = 1280 / 2
global_game_view_pixels_height : f32 = 720 / 2
global_game_texture_grid_cell_size : f32 = 32
global_number_grid_cells_axis_x : f32 = global_game_view_pixels_width / global_game_texture_grid_cell_size
global_number_grid_cells_axis_y : f32 = global_game_view_pixels_height / global_game_texture_grid_cell_size
global_sprite_sheet_cell_size : f32 = 32


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
}

Behavior :: enum {
	Face_Biscuit,
	Is_Biscuit,
	Move_Veritcally_On_Parent,
	Auto_Pass,
	Moveable,
	Hazard,
	Flip_V,
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
	tex_id : Texture_Id,
	target_entity_handle_to_pass_to: Entity_Handle,
	lerp_pos : Lerp_Position,
	behaviors : bit_set[Behavior],
	speed : f32,
	veritcal_move_bounds : f32,
	wait_timer : f32,
	wait_timer_duration : f32,
	collider : rl.Rectangle,
}

entities : Handle_Array(Entity, Entity_Handle)

biscuit_h : Entity_Handle

set_parent :: proc(entity_handle, parent_entity_handle : Entity_Handle)
{
	e_ptr := ha_get_ptr(entities, entity_handle)
	e_ptr.parent_entity_handle = parent_entity_handle
}

set_target_to_pass_to :: proc(entity_handle, target_entity_handle : Entity_Handle)
{
	ptr := ha_get_ptr(entities, entity_handle)
	ptr.target_entity_handle_to_pass_to = target_entity_handle
}

create_level_1 :: proc()
{
	ha_clear(&entities)
	e1_h := ha_add(&entities, Entity { pos = [2]f32{4, 6}, tex_id = .Person,  behaviors = {.Face_Biscuit}})
	e2_h := ha_add(&entities, Entity { pos = [2]f32{6, 6}, tex_id = .Person,  behaviors = {.Face_Biscuit}})
	e3_h := ha_add(&entities, Entity { pos = [2]f32{8, 6}, tex_id = .Person,  behaviors = {.Face_Biscuit}})
	e4_h := ha_add(&entities, Entity { pos = [2]f32{10, 5}, tex_id = .Person,  behaviors = {.Face_Biscuit}})
	e5_h := ha_add(&entities, Entity { pos = [2]f32{12, 6}, tex_id = .Person,  behaviors = {.Face_Biscuit}})
	e6_h := ha_add(&entities, Entity { pos = [2]f32{14, 6}, tex_id = .Person,  behaviors = {.Face_Biscuit}})
	e7_h := ha_add(&entities, Entity { pos = [2]f32{16, 6}, tex_id = .Person,  behaviors = {.Face_Biscuit}})
	e8_h := ha_add(&entities, Entity { pos = [2]f32{20, 6}, tex_id = .Cannon,  behaviors = {.Auto_Pass, .Face_Biscuit}, wait_timer_duration = 0.25,})
	e9_h := ha_add(&entities, Entity { pos = [2]f32{22, 6}, tex_id = .Unicycle1,  behaviors = {.Moveable, .Face_Biscuit}, speed = 6})
	e10_h := ha_add(&entities, Entity { pos = [2]f32{26, 6}, tex_id = .Person, behaviors = {.Face_Biscuit}})
	e11_h := ha_add(&entities, Entity { pos = [2]f32{0, 0}, tex_id = .Person, behaviors = {.Face_Biscuit, .Move_Veritcally_On_Parent}, speed = 4})

	h1_h := ha_add(&entities, Entity { pos = [2]f32{0, 0}, tex_id = .Shark, behaviors = {.Hazard, .Move_Veritcally_On_Parent, .Flip_V}, collider = rl.Rectangle{0,0,1,1}, speed = 3 })
	
	av1_h := ha_add(&entities, Entity { pos = [2]f32{18, 4}, veritcal_move_bounds = 5}) // anchor for next entity
	av2_h := ha_add(&entities, Entity { pos = [2]f32{24, 5}, veritcal_move_bounds = 3}) // anchor for next

	set_parent(e11_h, av1_h)
	set_parent(h1_h, av2_h)


	biscuit_h = ha_add(&entities, Entity { parent_entity_handle = e1_h, pos = [2]f32{0,0}, tex_id =.Regular_Biscuit, behaviors = { .Is_Biscuit }, collider = rl.Rectangle { 0.33, 0.33, 0.33, 0.33} })
	set_parent(biscuit_h, e1_h)

	pass_ring := [?]Entity_Handle{e1_h, e2_h, e3_h, e4_h, e5_h, e6_h, e7_h, e11_h, e8_h, e9_h, e10_h, }
	
	for i := 0; i < len(pass_ring); i+=1
	{
		next_i := (i + 1) % len(pass_ring) // treat it like a ring for now
		this_h := pass_ring[i]
		next_h := pass_ring[next_i]
		set_target_to_pass_to(this_h, next_h)
	}
}

// entities := [?]Entity {
// 	{ pos = [2]f32{0,0}, target_entity_id_to_pass_to = Entity_Id(1)},
// 	{ pos = [2]f32{4, 6}, tex_id = .Person, target_entity_id_to_pass_to = Entity_Id(2), behaviors = {.Face_Biscuit}},
// 	{ pos = [2]f32{6, 6}, tex_id = .Person, target_entity_id_to_pass_to = Entity_Id(3), behaviors = {.Face_Biscuit}},
// 	{ pos = [2]f32{8, 6}, tex_id = .Person, target_entity_id_to_pass_to = Entity_Id(4), behaviors = {.Face_Biscuit}},
// 	{ pos = [2]f32{10, 5}, tex_id = .Person, target_entity_id_to_pass_to = Entity_Id(5), behaviors = {.Face_Biscuit}},
// 	{ pos = [2]f32{12, 6}, tex_id = .Person, target_entity_id_to_pass_to = Entity_Id(6), behaviors = {.Face_Biscuit}},
// 	{ pos = [2]f32{14, 6}, tex_id = .Person, target_entity_id_to_pass_to = Entity_Id(7), behaviors = {.Face_Biscuit}},
// 	{ pos = [2]f32{16, 6}, tex_id = .Person, target_entity_id_to_pass_to = Entity_Id(9), behaviors = {.Face_Biscuit}},
// 	{ pos = [2]f32{18, 4}, veritcal_move_bounds = 5}, // anchor for next entity
// 	{ parent_entity_id = Entity_Id(8), pos = [2]f32{0, 0}, tex_id = .Person, target_entity_id_to_pass_to = Entity_Id(10), behaviors = {.Face_Biscuit, .Move_Veritcally_On_Parent}, speed = 4},
// 	{ pos = [2]f32{20, 6}, tex_id = .Cannon, target_entity_id_to_pass_to = Entity_Id(11), behaviors = {.Auto_Pass, .Face_Biscuit}, wait_timer_duration = 0.25,},
// 	{ pos = [2]f32{22, 6}, tex_id = .Unicycle1, target_entity_id_to_pass_to = Entity_Id(14), behaviors = {.Moveable, .Face_Biscuit}, speed = 6},
// 	{ pos = [2]f32{24, 5}, veritcal_move_bounds = 3}, // anchor for next
// 	{parent_entity_id = Entity_Id(12), pos = [2]f32{0, 0}, tex_id = .Shark, target_entity_id_to_pass_to = Entity_Id(1), behaviors = {.Hazard, .Move_Veritcally_On_Parent, .Flip_V}, collider = rl.Rectangle{0,0,1,1}, speed = 3 },
// 	{ pos = [2]f32{26, 6}, tex_id = .Person, target_entity_id_to_pass_to=Entity_Id(1), behaviors = {.Face_Biscuit}},
// 	{ parent_entity_id = Entity_Id(1), pos = [2]f32{0,0}, tex_id =.Regular_Biscuit, behaviors = { .Is_Biscuit }, collider = rl.Rectangle { 0.33, 0.33, 0.33, 0.33} },
// 	// just a bunch of placeholders
// 	{},
// 	{},
// 	{},
// 	{},
// 	{},
// 	{},
// 	{},
// 	{},
// 	{},
// 	{},
// 	{},
// 	{},
// 	{},
// 	{},
// 	{ parent_entity_id = Entity_Id(8), pos = [2]f32{0,0}, tex_id = .Rope_Ladder, },
// 	{ parent_entity_id = Entity_Id(8), pos = [2]f32{0,1}, tex_id = .Rope_Ladder, },
// 	{ parent_entity_id = Entity_Id(8), pos = [2]f32{0,2}, tex_id = .Rope_Ladder, },
// 	{ parent_entity_id = Entity_Id(8), pos = [2]f32{0,3}, tex_id = .Rope_Ladder, },
// 	{ parent_entity_id = Entity_Id(8), pos = [2]f32{0,4}, tex_id = .Rope_Ladder, },
// }

/**
 * Also, i was trying to think in terms of some Pass_Behaviors if that makes sense.

For instance:
- Auto-target the next entity with lerp (current): Pass directly to a target with a specified amount of time. The new target will become biscuit holder.
- Shoot in-direction at constant speed: "shoots" the biscuit in whatever direction the entity is set to throw it in. Whatever entity that collides with it will become the new biscuit holder
- Auto-target the next entity with constant speed: Pass directly to a target with a specified throw speed. The new target will become the biscuit holder.

Then for entity behavior i was thinking there'd be something like Biscuit_Holder_Behaviors:
- target only one entity
- choose between multiple targets
- aim direction
- move self left and right
- move self up and down

IDK if that makes sense. Looking for some feedback
so i was thinking, can we also get a "cursor" looking thing like in yoshi's island with he's throwing eggs?
*/




hot_script :: proc()
{
	// this is all just ideas. not sure if it will play out in practice.
	// I was moreso thinking of ways that brian can quickly create levels and layouts if writing code is the quickest way
	// the idea is that there is this function which acts as a script that will run once on a hot-reload of the game

	// Everything in this function is meant to be treated as if it were a one-shot script
	// one you hot reload the game, it will do whatever u tell it. If you run it again, it will do what u tell it again
	// so, if you run the script twice to create persons, it will create those persons AGAIN

	// you can even run single commands like:
	//
	// save_level()
	//
	// which will just save the working state of the level
	//
	// or
	//
	// reset_level_to_initial_state() which will set things to their initial state, including the biscuit back to it's initial holder
	//
	//
	// or something more complex
	// here are some examples

	// switch_level : changes level, all unsaved changes will be lost

	// restart_level_to_initial_state()
	// switch_level()
	// save()
	// create_person()
	// assign_initial_biscuit_holder(id)
	// create_jumping_shark(top_of_jump, length, offset, )
	// create_ladder_climber(top_of_ladder, length, offset)
	// create_unicyclist(leftmost_pos, allowable_travel_length, offset)
	// pass_directly_to_target(from, to)
	// auto_shoot_in_direction(from, direction)
	

}


Window_Save_Data :: struct 
{
    x, y, width, height : i32,
}


Root_State :: enum 
{
    Main_Menu,
    Game,
}


Game_Memory :: struct 
{
    root_state :                          Root_State,

    // VIEW
    game_render_target :                  rl.RenderTexture,

    // TODO(jblat): not filled with anything
    texture_sprite_sheet :                rl.Texture,
    rectangle :                           rl.Rectangle,
    rectangle_color :                     rl.Color,
    rectangle_lerp_position :             Lerp_Position,

	textures : [Texture_Id]rl.Texture,

	camera : rl.Camera2D,

    // Font
    font :                                rl.Font,

    // DEBUG
    dbg_show_grid :                       bool,
    dbg_show_level :                      bool,
    dbg_is_frogger_unkillable :           bool,
    dbg_show_entity_bounding_rectangles : bool,
    dbg_speed_multiplier :                f32,
    dbg_camera_offset :                   [2]f32,
    dbg_camera_zoom :                     f32,
    music :                               rl.Sound,
    pause :                               bool,
}


gmem : ^Game_Memory


// animation_player_advance :: proc(animation_player: ^Animation_Player, dt: f32) -> (just_finished: bool)
// {
// 	just_finished = false

// 	if !animation_player.timer.playing
// 	{
// 		return
// 	}

// 	animation_frames := global_sprite_animations[animation_player.animation_name]
// 	duration := animation_get_duration(animation_player.fps, len(animation_frames))
// 	animation_player.timer.t += dt

// 	if animation_player.timer.t > duration && !animation_player.timer.loop
// 	{
// 		animation_player.timer.playing = false
// 		just_finished = true
// 	}

// 	return 
// }


// entity_get_root_pos :: proc(id : Entity_Id) -> [2]f32
// {
	
// 	entity := entities[id]
// 	root_pos := entity.pos
	
// 	parent_entity_id := entity.parent_entity_id
// 	parent_entity := entities[Root_Entity_Id]

// 	if id == parent_entity_id
// 	{
// 		// parent is itself, so... yeah, we just treat this that its the root
// 		return root_pos
// 	}

// 	for parent_entity_id != Entity_Id(0)
// 	{
// 		parent_entity = entities[parent_entity_id]
// 		root_pos += parent_entity.pos
// 		parent_entity_id = parent_entity.parent_entity_id
// 	}

// 	return root_pos
// }


entity_get_root_pos :: proc(handle : Entity_Handle) -> [2]f32
{
	
	entity, _ := ha_get(entities, handle)
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
		parent_entity, _ = ha_get(entities, parent_entity_handle)
		root_pos += parent_entity.pos
		parent_entity_handle = parent_entity.parent_entity_handle
	}

	return root_pos
}


// entity_get_root_collider :: proc(id : Entity_Id) -> rl.Rectangle
// {
// 	root_pos := entity_get_root_pos(id)
// 	collider := entities[id].collider
// 	root_collider := rl.Rectangle {
// 		root_pos.x + collider.x,
// 		root_pos.y + collider.y,
// 		collider.width,
// 		collider.height,
// 	}
// 	return root_collider
// }

entity_get_root_collider :: proc(handle : Entity_Handle) -> rl.Rectangle
{
	root_pos := entity_get_root_pos(handle)
	e, _ := ha_get(entities, handle)
	collider := e.collider
	root_collider := rl.Rectangle {
		root_pos.x + collider.x,
		root_pos.y + collider.y,
		collider.width,
		collider.height,
	}
	return root_collider
}

// entity_root_pos_to_relative_pos :: proc(root_pos : [2]f32, relative_to_id : Entity_Id) -> [2]f32
// {
// 	relative_root_pos := entity_get_root_pos(relative_to_id)
//     return root_pos - relative_root_pos
// }

entity_root_pos_to_relative_pos :: proc(root_pos : [2]f32, relative_to_handle : Entity_Handle) -> [2]f32
{
	relative_root_pos := entity_get_root_pos(relative_to_handle)
    return root_pos - relative_root_pos
}

// entity_find_first_matching_behavior :: proc(behaviors : bit_set[Behavior]) -> Entity_Id
// {
// 	for entity, id in entities
//     {
//     	e_id := Entity_Id(id)
//     	if behaviors == entity.behaviors
//     	{
//     		return e_id
//     	}
//     }

//     return Entity_Id(0)
// }

entity_find_first_matching_behavior :: proc(behaviors : bit_set[Behavior]) -> Entity_Handle
{
	entity_iter := ha_make_iter(entities)
	for entity, handle in ha_iter(&entity_iter)
	{
		if behaviors == entity.behaviors
		{
			return handle
		}
	}
	
    return Entity_Handle{}
}


// pass_biscuit :: proc(biscuit_id : Entity_Id)
// {
// 	biscuit := &entities[biscuit_id]
// 	biscuit_root_pos := entity_get_root_pos(biscuit_id)
// 	parent := entities[biscuit.parent_entity_id]

// 	next_parent := parent.target_entity_id_to_pass_to
// 	biscuit.parent_entity_id = next_parent
// 	biscuit.pos = entity_root_pos_to_relative_pos(biscuit_root_pos, biscuit.parent_entity_id)

// 	lerp_position_start(&biscuit.lerp_pos, 0.3, biscuit.pos, [2]f32{0,0})

// 	next_parent_ref := &entities[next_parent]
// 	if .Auto_Pass in next_parent_ref.behaviors
// 	{
// 		// next_parent_ref.wait_timer = next_parent_ref.wait_timer_duration
// 	}
// }

pass_biscuit :: proc(biscuit_handle : Entity_Handle)
{
	biscuit := ha_get_ptr(entities, biscuit_handle)
	biscuit_root_pos := entity_get_root_pos(biscuit_handle)
	parent := ha_get_ptr(entities, biscuit.parent_entity_handle)

	next_parent_handle := parent.target_entity_handle_to_pass_to
	biscuit.parent_entity_handle = next_parent_handle
	biscuit.pos = entity_root_pos_to_relative_pos(biscuit_root_pos, biscuit.parent_entity_handle)

	lerp_position_start(&biscuit.lerp_pos, 0.3, biscuit.pos, [2]f32{0,0})
}


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
    rl.InitWindow(window_width, window_height, "Odin Template")
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
    }

    for bytes, tex_id in texture_bytes_png_map_to_load
    {
    	if tex_id == .None do continue
    	img := rl.LoadImageFromMemory(".png", &bytes[0], i32(len(bytes)))
    	gmem.textures[tex_id] = rl.LoadTextureFromImage(img)
    	rl.UnloadImage(img)
    }

    create_level_1()

}


root_state_main_menu_enter :: proc() 
{
    gmem.root_state = .Main_Menu

}

root_state_game :: proc() 
{

    if rl.IsKeyPressed(.ENTER) 
    {
        gmem.pause = !gmem.pause
    }

    if rl.IsKeyPressed(.BACKSPACE) 
    {
        gmem.pause = !gmem.pause
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
        scale := min(f32(rl.GetScreenWidth()) / global_game_view_pixels_width, f32(rl.GetScreenHeight()) / global_game_view_pixels_height)

        // Update virtual mouse (clamped mouse value behind game screen)
        mouse := rl.GetMousePosition()
        virtualMouse := [2]f32{0, 0}
        virtualMouse.x = (mouse.x - (f32(rl.GetScreenWidth()) - (global_game_view_pixels_width * scale)) * 0.5) / scale
        virtualMouse.y = (mouse.y - (f32(rl.GetScreenHeight()) - (global_game_view_pixels_height * scale)) * 0.5) / scale
        virtualMouse = rl.Vector2Clamp(virtualMouse, [2]f32{0, 0}, [2]f32{global_game_view_pixels_width, global_game_view_pixels_height})
        virtualMouse -= gmem.camera.offset
        virtualMouse += gmem.camera.target
        virtualMouse.x /= gmem.camera.zoom
        virtualMouse.y /= gmem.camera.zoom
        grid_mouse := [2]f32{virtualMouse.x / global_game_texture_grid_cell_size, virtualMouse.y / global_game_texture_grid_cell_size}

        if rl.IsMouseButtonPressed(.LEFT) 
        {
            lerp_position_start(&gmem.rectangle_lerp_position, 0.15, [2]f32{gmem.rectangle.x, gmem.rectangle.y}, grid_mouse)


        }

        if gmem.rectangle_lerp_position.timer.t < gmem.rectangle_lerp_position.timer.duration 
        {
            new_pos := lerp_position_advance(&gmem.rectangle_lerp_position, frame_time)
            gmem.rectangle.x = new_pos.x
            gmem.rectangle.y = new_pos.y
        }

       	biscuit_id := entity_find_first_matching_behavior({.Is_Biscuit})

   		biscuit := ha_get_ptr(entities, biscuit_h)
   		biscuit_parent, _ := ha_get(entities, biscuit.parent_entity_handle)

   		can_manually_pass_biscuit := rl.IsKeyPressed(.SPACE) && biscuit.lerp_pos.timer.t >= biscuit.lerp_pos.timer.duration && !(.Auto_Pass in biscuit_parent.behaviors)
       	if can_manually_pass_biscuit
       	{
       		pass_biscuit(biscuit_id)
       	}

       	if biscuit.lerp_pos.timer.t < biscuit.lerp_pos.timer.duration
       	{
       		new_pos, just_finished := lerp_position_advance_and_notify_just_finished(&biscuit.lerp_pos, frame_time)
       		biscuit.pos = new_pos
       		if just_finished
       		{
       			parent_ptr := ha_get_ptr(entities, biscuit.parent_entity_handle)
       			if .Auto_Pass in parent_ptr.behaviors
       			{
					parent_ptr.wait_timer = parent_ptr.wait_timer_duration       				
       			}
       		}
       	}

       	{ // biscuit collides with things
       		entity_iter := ha_make_iter(entities)
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
       					biscuit_relative_to_return_parent := entity_root_pos_to_relative_pos(biscuit_root_pos, entity.target_entity_handle_to_pass_to)
       					biscuit.parent_entity_handle = entity.target_entity_handle_to_pass_to
       					biscuit.pos = [2]f32{0,0}
       					biscuit.lerp_pos.timer.t = biscuit.lerp_pos.timer.duration      				
   					}
       			}
       		}
       	}

       	{ // general behvaior updates
       		entity_iter := ha_make_iter(entities)
       		for entity, handle in ha_iter(&entity_iter)
       		{
       			entity_ptr := ha_get_ptr(entities, handle)
       			if .Move_Veritcally_On_Parent in entity.behaviors
       			{
   					min_y : f32 = 0
   					parent_entity, _ := ha_get(entities, entity.parent_entity_handle)
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
       		}
       	}

       	{ // biscuit affecting parent
       		entity_iter := ha_make_iter(entities)
       		for entity, handle in ha_iter(&entity_iter)
       		{
       			if .Is_Biscuit in entity.behaviors
       			{
       				parent_ptr := ha_get_ptr(entities, entity.parent_entity_handle)
       				if .Auto_Pass in parent_ptr.behaviors
       				{
       					
       					just_finished := countdown_and_notify_just_finished(&parent_ptr.wait_timer, frame_time)
       					if just_finished
       					{
       						pass_biscuit(handle)
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
       			}
       		}
       	}

       	{ // moving
       		entity_iter := ha_make_iter(entities)
       		for entity, handle in ha_iter(&entity_iter)
       		{
       			entity_ptr := ha_get_ptr(entities, handle)
       			entity_ptr.pos += entity_ptr.vel * frame_time
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


    // NOTE(jblat): For mouse, see: https://github.com/raysan5/raylib/blob/master/examples/core/core_window_letterbox.c


    
    {     // DRAW TO RENDER TEXTURE


        gmem.camera.offset = gmem.dbg_camera_offset
        gmem.camera.offset.x += global_game_view_pixels_width/2
        gmem.camera.offset.y += global_game_view_pixels_height/2
        gmem.camera.zoom = gmem.dbg_camera_zoom


		biscuit_root_pos := entity_get_root_pos(biscuit_h)
		actual_pos := rlgrid.get_actual_pos(biscuit_root_pos, 32)
		gmem.camera.target = actual_pos 
        	
        
        rl.BeginTextureMode(gmem.game_render_target)

        rl.BeginMode2D(gmem.camera)

        rl.ClearBackground(rl.LIGHTGRAY)


        
        {
            rlgrid.draw_rectangle_on_grid_justified(gmem.rectangle, gmem.rectangle_color, global_game_texture_grid_cell_size, .Centered, .Centered)
        }

        {
        	entity_iter := ha_make_iter(entities)
        	for entity, handle in ha_iter(&entity_iter)
        	{
        		tex := gmem.textures[entity.tex_id]
        		
        		root_pos := entity_get_root_pos(handle)

        		tex_width_f := f32(tex.width)
        		tex_height_f := f32(tex.height)
        		src := rl.Rectangle {0,0, 1, 1}
        		dst := rl.Rectangle {root_pos.x, root_pos.y, 1, 1}

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


        		rlgrid.draw_grid_texture_clip_on_grid(tex, src, 32, dst, 32, 0, flip_x = flip_x, flip_y = flip_y)

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
     			entity_iter := ha_make_iter(entities)
     			for entity, handle in ha_iter(&entity_iter)
     			{
     				if entity.veritcal_move_bounds > 0
     				{
     					r := rl.Rectangle { entity.pos.x, entity.pos.y, 1, entity.veritcal_move_bounds}
     					rlgrid.draw_rectangle_on_grid(r, rl.Color{255,0,0,50}, 32)
     				}
     				collider_r := entity_get_root_collider(handle)
     				rlgrid.draw_rectangle_on_grid(collider_r, rl.Color{0,0,255,50}, 32)
     			}
     		}


        }


        rl.EndMode2D()

        {
        	text_pos_of_rectangle_cursor := fmt.ctprintf("(%.2f, %.2f)", gmem.rectangle.x, gmem.rectangle.y)
            rlgrid.draw_text_on_grid(gmem.font, text_pos_of_rectangle_cursor, [2]f32{0,0}, 0.5, 0, rl.BLACK, global_game_texture_grid_cell_size)
        }

        rl.EndTextureMode()
    }
}


root_state_main_menu :: proc() 
{
    @(static) visible : bool
    blink_timer_duration :: 0.3
    @(static) blink_timer : f32 = blink_timer_duration

    dt := rl.GetFrameTime()
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
        gmem.root_state = .Game
    }
    rl.BeginTextureMode(gmem.game_render_target)
    defer rl.EndTextureMode()

    rl.ClearBackground(rl.BLACK)
    title_centered_pos := [2]f32{global_number_grid_cells_axis_x / 2, 3}
    rlgrid.draw_text_on_grid_centered(gmem.font, "BISCUIT BOY", title_centered_pos, 2, 0, rl.GREEN, global_game_texture_grid_cell_size)
    title_centered_pos.y += 2
    rlgrid.draw_text_on_grid_centered(gmem.font, "AND THE MAGIC TEA CUP", title_centered_pos, 1, 0, rl.GREEN, global_game_texture_grid_cell_size)
    title_centered_pos.y += 2


    if visible 
    {
        press_enter_centered_pos := [2]f32{global_number_grid_cells_axis_x / 2, 8}
        rlgrid.draw_text_on_grid_centered(gmem.font, "press enter to play", press_enter_centered_pos, 0.7, 0, rl.WHITE, global_game_texture_grid_cell_size)
    }

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
