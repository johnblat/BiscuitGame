package game


percentage_remaining :: proc(v, max : f32) -> f32 
{
    return 1.0 - percentage_full(v, max)
}


percentage_full :: proc(v, max : f32) -> f32 
{
    return v / max
}

percentage_done :: proc(v, max : f32) -> f32 
{
    return percentage_full(v, max)
}
