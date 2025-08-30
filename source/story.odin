package game

import rl "vendor:raylib"

Story_Mode :: enum
{
	Opening,
	Ending,
}

Story_Page :: struct
{
	tex_id : Texture_Id,
	voice : Sound_Id,
}

story_pages_opening := [?]Story_Page {
	{ tex_id = .Opening_Waving, voice = .Voice_Bumper_Circus },
	{ tex_id = .Opening_Tea_Crayons, voice = .Voice_Bumper_Circus },
	{ tex_id = .Opening_Music, voice = .Voice_Bumper_Circus },
}

story_pages_ending := [?]Story_Page {
	{ tex_id = .Ending_Waving, voice = .Voice_Bumper_Circus },
	{ tex_id = .Ending_Parents, voice = .Voice_Bumper_Circus },
	{ tex_id = .Ending_Soveneir, voice = .Voice_Bumper_Circus },
}

story_books := [Story_Mode][]Story_Page{
	.Opening = story_pages_opening[:],
	.Ending = story_pages_ending[:],
}


root_state_story_enter :: proc()
{
	gmem.root_state = .Story
	gmem.story_page_index = 0
	
	// If entering ending cutscenes, load and play the monkey track
	if gmem.story_mode_current == .Ending {
		rl.UnloadMusicStream(gmem.music)
		gmem.music = rl.LoadMusicStream("audio/monkey_full_160_extended.ogg")
		rl.PlayMusicStream(gmem.music)
	}
}

root_state_story :: proc()
{
	// Update music stream for both opening and ending cutscenes
	rl.UpdateMusicStream(gmem.music)
	
	story_pages := story_books[gmem.story_mode_current]

	is_on_last_page := gmem.story_page_index >= len(story_pages) - 1
	user_wants_to_advance := rl.IsKeyPressed(.ENTER)

	should_go_to_next_state := is_on_last_page && user_wants_to_advance
	
	if should_go_to_next_state
	{
		if gmem.story_mode_current == .Opening
		{
			// Stop the music before transitioning to bumper (which has its own audio)
			rl.StopMusicStream(gmem.music)
			gmem.story_mode_current = .Ending
			gmem.level_index_current = 0
			root_state_bumper_enter()
			return
		}
		else
		{
			// Ending cutscenes finished, stop the monkey track before returning to main menu
			rl.StopMusicStream(gmem.music)
			gmem.story_mode_current = .Opening
			gmem.level_index_current = 0
			gmem.main_menu_show_credits = true
			root_state_main_menu_enter()
			return 
		}
	}

	if user_wants_to_advance
	{
		gmem.story_page_index += 1
	}

	rl.BeginTextureMode(gmem.game_render_target)
	rl.ClearBackground(rl.BLACK)
	tex := gmem.textures[story_pages[gmem.story_page_index].tex_id]
	rl.DrawTexturePro(tex, rl.Rectangle{0,0,f32(tex.width), f32(tex.height)}, rl.Rectangle{0,0,global_game_view_pixels_width, global_game_view_pixels_height},[2]f32{0,0}, 0, rl.WHITE )
	rl.EndTextureMode()
}