package example

import "core:c"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import rl "vendor:raylib"

import

import rlgrid "../rlgrid"

bytes_font_data := #load("../../assets/joystix monospace.otf")


global_filename_window_save_data := "window_save_data.jam"
global_game_view_pixels_width : f32 = 1280
global_game_view_pixels_height : f32 = 720
global_game_texture_grid_cell_size : f32 = 64
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
}

Game_State :: enum 
{
    Playing,
    Success,
    Failed,
}

Character :: struct 
{
    position :       [2]f32,
    has_biscuit :    bool,
    animation_time : f32,
    is_active :      bool,
}

Biscuit :: struct 
{
    position :         [2]f32,
    velocity :         [2]f32,
    rotation :         f32,
    is_flying :        bool,
    target_character : int,
}

Timing_Indicator :: struct 
{
    position :  f32,
    direction : f32,
    speed :     f32,
}

Particle :: struct 
{
    position :  [2]f32,
    velocity :  [2]f32,
    life_time : f32,
    color :     rl.Color,
}

CHARACTER_COUNT :: 6
PERFECT_TIMING_WINDOW :: 0.15
GOOD_TIMING_WINDOW :: 0.35
TOSS_VELOCITY :: 400.0
GRAVITY :: 980.0
TIMING_BAR_WIDTH :: 8.0
TIMING_BAR_HEIGHT :: 0.8
MAX_PARTICLES :: 100

Game_Memory :: struct 
{
    root_state :                          Root_State,
    game_state :                          Game_State,

    // VIEW
    game_render_target :                  rl.RenderTexture,

    // Game Elements
    characters :                          [CHARACTER_COUNT]Character,
    biscuit :                             Biscuit,
    timing_indicator :                    Timing_Indicator,
    current_character :                   int,

    // Scoring
    score :                               int,
    combo :                               int,

    // Particles
    particles :                           [MAX_PARTICLES]Particle,
    particle_count :                      int,

    // TODO(jblat): not filled with anything
    texture_sprite_sheet :                rl.Texture,
    rectangle :                           rl.Rectangle,
    rectangle_color :                     rl.Color,
    rectangle_lerp_position :             Lerp_Position,

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
    rl.InitWindow(window_width, window_height, "Biscuit Toss")
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

init_game :: proc() 
{
    // Initialize characters
    character_spacing := global_game_view_pixels_width / f32(CHARACTER_COUNT + 1)
    for i in 0 ..< CHARACTER_COUNT 
    {
        gmem.characters[i].position.x = character_spacing * f32(i + 1)
        gmem.characters[i].position.y = global_game_view_pixels_height * 0.7
        gmem.characters[i].has_biscuit = i == 0
        gmem.characters[i].animation_time = 0
        gmem.characters[i].is_active = i == 0
    }

    // Initialize biscuit
    gmem.biscuit.position = gmem.characters[0].position
    gmem.biscuit.position.y -= 30
    gmem.biscuit.is_flying = false
    gmem.biscuit.rotation = 0
    gmem.biscuit.target_character = 1

    // Initialize timing indicator
    gmem.timing_indicator.position = 0.5
    gmem.timing_indicator.direction = 1
    gmem.timing_indicator.speed = 1.5

    // Reset game state
    gmem.current_character = 0
    gmem.score = 0
    gmem.combo = 0
    gmem.game_state = .Playing
    gmem.particle_count = 0
}

@(export)
game_init :: proc() 
{
    gmem = new(Game_Memory)

    gmem.root_state = .Main_Menu

    game_render_target := rl.LoadRenderTexture(i32(global_game_view_pixels_width), i32(global_game_view_pixels_height))
    rl.SetTextureFilter(game_render_target.texture, rl.TextureFilter.BILINEAR)
    rl.SetTextureWrap(game_render_target.texture, .CLAMP)

    gmem.game_render_target = game_render_target

    gmem.dbg_show_grid = false
    gmem.dbg_is_frogger_unkillable = false

    gmem.font = rl.LoadFontFromMemory(".otf", &bytes_font_data[0], i32(len(bytes_font_data)), 256, nil, 0)

    gmem.dbg_camera_zoom = 1.0

    gmem.dbg_speed_multiplier = 1.0

    gmem.rectangle = rl.Rectangle{0, 0, 1, 1}
    gmem.rectangle_color = rl.GREEN

    init_game()
}


root_state_main_menu_enter :: proc() 
{
    gmem.root_state = .Main_Menu
}

spawn_particles :: proc(position : [2]f32, count : int, color : rl.Color) 
{
    for i in 0 ..< count 
    {
        if gmem.particle_count >= MAX_PARTICLES do break

        particle := &gmem.particles[gmem.particle_count]
        particle.position = position
        particle.velocity.x = f32(rl.GetRandomValue(-100, 100))
        particle.velocity.y = f32(rl.GetRandomValue(-200, -50))
        particle.life_time = 1.0
        particle.color = color
        gmem.particle_count += 1
    }
}

update_particles :: proc(dt : f32) 
{
    i := 0
    for i < gmem.particle_count 
    {
        particle := &gmem.particles[i]
        particle.position += particle.velocity * dt
        particle.velocity.y += GRAVITY * 0.5 * dt
        particle.life_time -= dt

        if particle.life_time <= 0 
        {
            gmem.particles[i] = gmem.particles[gmem.particle_count - 1]
            gmem.particle_count -= 1
        }
         else 
        {
            i += 1
        }
    }
}

calculate_toss_velocity :: proc(from : [2]f32, to : [2]f32) -> [2]f32 
{
    dx := to.x - from.x
    dy := to.y - from.y

    // Calculate time to reach target
    t := math.sqrt(2 * math.abs(dy) / GRAVITY) * 2
    if t <= 0 do t = 1

    // Calculate initial velocities
    vx := dx / t
    vy := -GRAVITY * t / 2 + dy / t

    return {vx, vy}
}

root_state_game :: proc() 
{
    dt := rl.GetFrameTime()

    if gmem.game_state != .Playing 
    {
        if rl.IsKeyPressed(.R) 
        {
            init_game()
        }
        return
    }

    // Update timing indicator
    gmem.timing_indicator.position += gmem.timing_indicator.direction * gmem.timing_indicator.speed * dt
    if gmem.timing_indicator.position >= 1.0 
    {
        gmem.timing_indicator.position = 1.0
        gmem.timing_indicator.direction = -1
    }
     else if gmem.timing_indicator.position <= 0.0 
    {
        gmem.timing_indicator.position = 0.0
        gmem.timing_indicator.direction = 1
    }

    // Update character animations
    for i in 0 ..< CHARACTER_COUNT 
    {
        if gmem.characters[i].is_active 
        {
            gmem.characters[i].animation_time += dt * 2
        }
    }

    // Handle input
    if rl.IsKeyPressed(.SPACE) && !gmem.biscuit.is_flying && gmem.current_character < CHARACTER_COUNT - 1 
    {
        // Check timing
        center : f32 = 0.5
        distance := math.abs(gmem.timing_indicator.position - center)

        if distance <= PERFECT_TIMING_WINDOW 
        {
            // Perfect timing
            gmem.combo += 1
            gmem.score += 100 * gmem.combo
            spawn_particles(gmem.characters[gmem.current_character].position, 20, rl.GOLD)

            // Toss biscuit
            gmem.biscuit.is_flying = true
            from := gmem.characters[gmem.current_character].position
            to := gmem.characters[gmem.current_character + 1].position
            gmem.biscuit.velocity = calculate_toss_velocity(from, to)
            gmem.biscuit.target_character = gmem.current_character + 1
        }
         else if distance <= GOOD_TIMING_WINDOW 
        {
            // Good timing
            gmem.combo = 0
            gmem.score += 50

            // Toss biscuit
            gmem.biscuit.is_flying = true
            from := gmem.characters[gmem.current_character].position
            to := gmem.characters[gmem.current_character + 1].position
            gmem.biscuit.velocity = calculate_toss_velocity(from, to)
            gmem.biscuit.target_character = gmem.current_character + 1
        }
         else 
        {
            // Bad timing - biscuit falls
            gmem.combo = 0
            gmem.biscuit.is_flying = true
            gmem.biscuit.velocity = {f32(rl.GetRandomValue(-50, 50)), -200}
            gmem.biscuit.target_character = -1
            gmem.game_state = .Failed
        }
    }

    // Update biscuit physics
    if gmem.biscuit.is_flying 
    {
        gmem.biscuit.position += gmem.biscuit.velocity * dt
        gmem.biscuit.velocity.y += GRAVITY * dt
        gmem.biscuit.rotation += dt * 360

        // Check if caught
        if gmem.biscuit.target_character >= 0 && gmem.biscuit.target_character < CHARACTER_COUNT 
        {
            target := gmem.characters[gmem.biscuit.target_character].position
            distance := math.sqrt(
                math.pow(gmem.biscuit.position.x - target.x, 2) + math.pow(gmem.biscuit.position.y - target.y, 2),
            )

            if distance < 40 && gmem.biscuit.velocity.y > 0 
            {
                // Caught!
                gmem.biscuit.is_flying = false
                gmem.biscuit.position = target
                gmem.biscuit.position.y -= 30

                gmem.characters[gmem.current_character].has_biscuit = false
                gmem.characters[gmem.current_character].is_active = false
                gmem.current_character = gmem.biscuit.target_character
                gmem.characters[gmem.current_character].has_biscuit = true
                gmem.characters[gmem.current_character].is_active = true

                if gmem.current_character == CHARACTER_COUNT - 1 
                {
                    gmem.game_state = .Success
                    spawn_particles(target, 50, rl.GREEN)
                }
            }
        }

        // Check if fell
        if gmem.biscuit.position.y > global_game_view_pixels_height 
        {
            gmem.game_state = .Failed
        }
    }

    // Update particles
    update_particles(dt)
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
        rl.IsKeyPressed(.SPACE) ||
        rl.IsGamepadButtonPressed(0, .MIDDLE) ||
        rl.IsGamepadButtonPressed(0, .MIDDLE_LEFT) ||
        rl.IsGamepadButtonPressed(0, .MIDDLE_RIGHT) ||
        rl.IsGamepadButtonPressed(0, .RIGHT_FACE_DOWN)
    if is_input_start 
    {
        gmem.root_state = .Game
        init_game()
    }
    rl.BeginTextureMode(gmem.game_render_target)
    defer rl.EndTextureMode()

    rl.ClearBackground(rl.BLACK)
    title_centered_pos := [2]f32{global_number_grid_cells_axis_x / 2, 5}
    rlgrid.draw_text_on_grid_centered(
        gmem.font,
        "BISCUIT TOSS",
        title_centered_pos,
        2,
        0,
        rl.ORANGE,
        global_game_texture_grid_cell_size,
    )
    title_centered_pos.y += 2

    if visible 
    {
        press_enter_centered_pos := [2]f32{global_number_grid_cells_axis_x / 2, 8}
        rlgrid.draw_text_on_grid_centered(
            gmem.font,
            "press SPACE to play",
            press_enter_centered_pos,
            0.7,
            0,
            rl.WHITE,
            global_game_texture_grid_cell_size,
        )
    }
}

draw_game :: proc() 
{
    rl.BeginTextureMode(gmem.game_render_target)
    defer rl.EndTextureMode()

    // Background
    rl.ClearBackground({30, 30, 40, 255})

    // Draw ground
    rl.DrawRectangle(
        0,
        i32(global_game_view_pixels_height * 0.75),
        i32(global_game_view_pixels_width),
        i32(global_game_view_pixels_height * 0.25),
        {40, 40, 50, 255},
    )

    // Draw timing bar
    bar_y := global_game_view_pixels_height * 0.85
    bar_width := global_game_view_pixels_width * TIMING_BAR_WIDTH / 10
    bar_x := (global_game_view_pixels_width - bar_width) / 2

    // Background of timing bar
    rl.DrawRectangleRec({bar_x, bar_y, bar_width, 40}, rl.DARKGRAY)

    // Good zone (yellow) - draw this first as it's larger
    good_width := bar_width * GOOD_TIMING_WINDOW * 2
    good_x := bar_x + (bar_width - good_width) / 2
    rl.DrawRectangleRec({good_x, bar_y, good_width, 40}, rl.YELLOW)

    // Perfect zone (green) - draw this on top as it's smaller
    perfect_width := bar_width * PERFECT_TIMING_WINDOW * 2
    perfect_x := bar_x + (bar_width - perfect_width) / 2
    rl.DrawRectangleRec({perfect_x, bar_y, perfect_width, 40}, rl.GREEN)

    // Timing indicator
    indicator_x := bar_x + bar_width * gmem.timing_indicator.position
    rl.DrawRectangleRec({indicator_x - 3, bar_y - 5, 6, 50}, rl.RED)

    // Draw characters
    for i in 0 ..< CHARACTER_COUNT 
    {
        char := &gmem.characters[i]
        color := rl.GRAY
        if char.is_active do color = rl.WHITE

        // Body
        body_y := char.position.y
        if char.is_active 
        {
            body_y += math.sin(char.animation_time) * 5
        }
        rl.DrawCircle(i32(char.position.x), i32(body_y), 25, color)

        // Head
        rl.DrawCircle(i32(char.position.x), i32(body_y - 35), 15, color)

        // Arms
        if char.has_biscuit 
        {
            rl.DrawLineEx({char.position.x - 20, body_y - 10}, {char.position.x - 10, body_y - 30}, 3, color)
            rl.DrawLineEx({char.position.x + 20, body_y - 10}, {char.position.x + 10, body_y - 30}, 3, color)
        }
         else 
        {
            rl.DrawLineEx({char.position.x - 20, body_y - 10}, {char.position.x - 30, body_y}, 3, color)
            rl.DrawLineEx({char.position.x + 20, body_y - 10}, {char.position.x + 30, body_y}, 3, color)
        }
    }

    // Draw biscuit
    rl.DrawCircleV(gmem.biscuit.position, 15, rl.BROWN)
    rl.DrawCircleV(gmem.biscuit.position, 12, {200, 150, 100, 255})

    // Draw some texture on biscuit
    for i in 0 ..< 3 
    {
        angle := gmem.biscuit.rotation + f32(i) * 120
        x := gmem.biscuit.position.x + math.cos(angle * math.PI / 180) * 5
        y := gmem.biscuit.position.y + math.sin(angle * math.PI / 180) * 5
        rl.DrawCircle(i32(x), i32(y), 2, rl.BROWN)
    }

    // Draw particles
    for i in 0 ..< gmem.particle_count 
    {
        particle := &gmem.particles[i]
        alpha := u8(particle.life_time * 255)
        color := particle.color
        color.a = alpha
        rl.DrawCircleV(particle.position, 3, color)
    }

    // Draw score
    score_text := fmt.tprintf("Score: %d", gmem.score)
    rl.DrawText(strings.clone_to_cstring(score_text, context.temp_allocator), 10, 10, 30, rl.WHITE)

    // Draw combo
    if gmem.combo > 0 
    {
        combo_text := fmt.tprintf("Combo x%d", gmem.combo)
        rl.DrawText(strings.clone_to_cstring(combo_text, context.temp_allocator), 10, 50, 25, rl.GOLD)
    }

    // Draw game state messages
    if gmem.game_state == .Success 
    {
        rlgrid.draw_text_on_grid_centered(
            gmem.font,
            "SUCCESS!",
            {global_number_grid_cells_axis_x / 2, 4},
            2,
            0,
            rl.GREEN,
            global_game_texture_grid_cell_size,
        )
        rlgrid.draw_text_on_grid_centered(
            gmem.font,
            "Press R to restart",
            {global_number_grid_cells_axis_x / 2, 6},
            1,
            0,
            rl.WHITE,
            global_game_texture_grid_cell_size,
        )
    }
     else if gmem.game_state == .Failed 
    {
        rlgrid.draw_text_on_grid_centered(
            gmem.font,
            "YOU DIED",
            {global_number_grid_cells_axis_x / 2, 4},
            2,
            0,
            rl.RED,
            global_game_texture_grid_cell_size,
        )
        rlgrid.draw_text_on_grid_centered(
            gmem.font,
            "Press R to restart",
            {global_number_grid_cells_axis_x / 2, 6},
            1,
            0,
            rl.WHITE,
            global_game_texture_grid_cell_size,
        )
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
        draw_game()
    }


    // rendering

    screen_width := f32(rl.GetScreenWidth())
    screen_height := f32(rl.GetScreenHeight())


    
    {     // DRAW TO WINDOW

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        src := rl.Rectangle {
            0,
            0,
            f32(gmem.game_render_target.texture.width),
            f32(-gmem.game_render_target.texture.height),
        }

        scale := min(screen_width / global_game_view_pixels_width, screen_height / global_game_view_pixels_height)

        window_scaled_width := global_game_view_pixels_width * scale
        window_scaled_height := global_game_view_pixels_height * scale

        dst := rl.Rectangle {
            (screen_width - window_scaled_width) / 2,
            (screen_height - window_scaled_height) / 2,
            window_scaled_width,
            window_scaled_height,
        }
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