package game


countdown_and_notify_just_finished :: proc(t : ^f32, dt : f32) -> (just_finished : bool) 
{
    is_already_completed := t^ <= 0.0
    countdown(t, dt)
    just_finished = t^ <= 0.0 && !is_already_completed
    return
}


countdown :: proc(t : ^f32, dt : f32) 
{
    t^ -= dt
    t^ = max(t^, 0.0)
}


countdown_is_playing :: proc(t : f32) -> bool 
{
    return t > 0.0
}
