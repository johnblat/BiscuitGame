package game

import "base:intrinsics"
import rl "vendor:raylib"
import "./rlgrid"


root_state_main_menu_enter :: proc() 
{
	rl.UnloadMusicStream(gmem.music)
	gmem.music = rl.LoadMusicStream("audio/biscuit.mp3")
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