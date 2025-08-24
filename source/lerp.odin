package game

Lerp_Timer :: struct 
{
    t :        f32,
    duration : f32,
}

Lerp_Position :: struct 
{
    timer :     Lerp_Timer,
    start_pos : [2]f32,
    end_pos :   [2]f32,
}

Lerp_Value :: struct 
{
    timer :     Lerp_Timer,
    start_val : f32,
    end_val :   f32,
}


add_capped :: proc(a, b, max : f32) -> f32 
{
    ret := a + b
    ret = min(ret, max)
    return ret
}

lerp_timer_is_playing :: proc(timer : Lerp_Timer) -> bool 
{
    is_playing := timer.t < timer.duration
    return is_playing
}


lerp_position_start :: proc(lerp : ^Lerp_Position, duration : f32, start_pos, end_pos : [2]f32) 
{
    lerp.timer.t = 0
    lerp.timer.duration = duration
    lerp.start_pos = start_pos
    lerp.end_pos = end_pos
}


lerp_position_progress :: proc(lerp : Lerp_Position) -> (progress_pos : [2]f32) 
{
    percentage_done := lerp.timer.t / lerp.timer.duration
    percentage_done = min(percentage_done, 1.0)
    progress_pos.x = (1.0 - percentage_done) * lerp.start_pos.x + percentage_done * lerp.end_pos.x
    progress_pos.y = (1.0 - percentage_done) * lerp.start_pos.y + percentage_done * lerp.end_pos.y
    return
}


lerp_position_advance :: proc(lerp : ^Lerp_Position, dt : f32) -> (progress_pos : [2]f32) 
{
    lerp.timer.t = add_capped(lerp.timer.t, dt, lerp.timer.duration)
    progress_pos = lerp_position_progress(lerp^)
    return
}


lerp_position_advance_and_notify_just_finished :: proc(lerp : ^Lerp_Position, dt : f32) -> (progress_pos : [2]f32, just_finished : bool) 
{
    is_already_finished := lerp.timer.t >= lerp.timer.duration
    progress_pos = lerp_position_advance(lerp, dt)
    is_now_finished := lerp.timer.t >= lerp.timer.duration
    if !is_already_finished && is_now_finished 
    {
        just_finished = true
    }
    return
}


lerp_value_start :: proc(lerp : ^Lerp_Value, start_val, end_val : f32) 
{
    lerp.timer.t = 0
    lerp.start_val = start_val
    lerp.end_val = end_val
}


lerp_value_progress :: proc(lerp : Lerp_Value) -> (progress_val : f32) 
{
    t := percentage_done(lerp.timer.t, lerp.timer.duration)
    t = min(t, 1.0)
    progress_val = (1.0 - t) * lerp.start_val + t * lerp.end_val
    return
}


lerp_value_advance :: proc(lerp : ^Lerp_Value, dt : f32) -> (progress_val : f32) 
{
    lerp.timer.t = add_capped(lerp.timer.t, dt, lerp.timer.duration)
    progress_val = lerp_value_progress(lerp^)
    return
}


lerp_value_advance_and_notify_just_finished :: proc(lerp : ^Lerp_Value, dt : f32) -> (progress_val : [2]f32, just_finished : bool) 
{
    is_already_finished := lerp.timer.t >= lerp.timer.duration
    progress_val = lerp_value_advance(lerp, dt)
    is_now_finished := lerp.timer.t >= lerp.timer.duration
    if !is_already_finished && is_now_finished 
    {
        just_finished = true
    }
    return
}
