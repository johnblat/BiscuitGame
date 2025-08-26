
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
