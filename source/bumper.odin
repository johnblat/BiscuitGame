package game

import rl "vendor:raylib"


Bumper :: struct
{
	level_idx : u32,
	tex_id : Texture_Id,
	voice_id : Sound_Id,
}


bumpers := [?]Bumper {
	{ level_idx = 0, tex_id = .Bumper_Circus, voice_id = .Voice_Bumper_Circus },
	{ level_idx = 1, tex_id = .Bumper_Unicycle, voice_id = .Voice_Bumper_Unicycle },
}


root_state_bumper_enter :: proc()
{
	gmem.root_state = .Bumper
	timer_duration : f32 = 2.0

	// gmem.bumper_texture = .Bumper_Circus
	gmem.bumper_fade_in_timer = timer_duration
	gmem.bumper_fade_out_timer = 0
	rl.PlaySound(gmem.bumper_sparkle_sound)
	gmem.bumper_did_voice_start = false

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

	
	default_bumper_index := 0
	bumper := bumpers[default_bumper_index]

	for b in bumpers
	{
		is_this_the_bumper_for_the_upcoming_level := b.level_idx == gmem.level_index_current
		if is_this_the_bumper_for_the_upcoming_level
		{
			bumper = b
			break
		}
	}

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
		rl.PlaySound(gmem.sounds[bumper.voice_id])
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
		voice_finished := !rl.IsSoundPlaying(gmem.sounds[bumper.voice_id])
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
		tex := gmem.textures[bumper.tex_id]
		rl.DrawTexturePro(tex, rl.Rectangle{0,0,f32(tex.width), f32(tex.height)}, rl.Rectangle{0,0,global_game_view_pixels_width, global_game_view_pixels_height},[2]f32{0,0}, 0, tint )
		rl.EndTextureMode()

	}

}

