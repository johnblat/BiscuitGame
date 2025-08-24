package game

import "core:c"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import rl "vendor:raylib"

import rlgrid "./rlgrid"

bytes_font_data := #load("../assets/joystix monospace.otf")


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
    rl.SetTextureFilter(game_render_target.texture, rl.TextureFilter.BILINEAR)
    rl.SetTextureWrap(game_render_target.texture, .CLAMP) // this stops sub-pixel artifacts on edges of game texture

    gmem.game_render_target = game_render_target

    gmem.dbg_show_grid = false
    gmem.dbg_is_frogger_unkillable = false

    gmem.font = rl.LoadFontFromMemory(".otf", &bytes_font_data[0], i32(len(bytes_font_data)), 256, nil, 0)

    gmem.dbg_camera_zoom = 1.0

    gmem.dbg_speed_multiplier = 1.0

    gmem.rectangle = rl.Rectangle{0, 0, 1, 1}
    gmem.rectangle_color = rl.GREEN
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
        virtualMouse -= gmem.dbg_camera_offset
        virtualMouse.x /= gmem.dbg_camera_zoom
        virtualMouse.y /= gmem.dbg_camera_zoom
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
        camera := rl.Camera2D \
        {
            offset   = gmem.dbg_camera_offset,
            target   = [2]f32{0, 0},
            rotation = 0,
            zoom     = gmem.dbg_camera_zoom,
        }

        rl.BeginTextureMode(gmem.game_render_target)

        rl.BeginMode2D(camera)

        rl.ClearBackground(rl.LIGHTGRAY)


        
        {
            rlgrid.draw_rectangle_on_grid_justified(gmem.rectangle, gmem.rectangle_color, global_game_texture_grid_cell_size, .Centered, .Centered)
        }

        if gmem.dbg_show_grid && gmem.dbg_camera_zoom > 0.09 
        {

            // 1) Convert all 4 screen corners to world space (handles offset, zoom, rotation).
            render_width := f32(gmem.game_render_target.texture.width)
            render_height := f32(gmem.game_render_target.texture.height)

            // Convert all 4 render texture corners to world space
            rc := [4][2]f32{{0, 0}, {render_width, 0}, {0, render_height}, {render_width, render_height}}

            wc := [4][2]f32{rl.GetScreenToWorld2D(rc[0], camera), rl.GetScreenToWorld2D(rc[1], camera), rl.GetScreenToWorld2D(rc[2], camera), rl.GetScreenToWorld2D(rc[3], camera)}

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
            thickness : f32 = (camera.zoom > 0.0) ? (1.0 / camera.zoom) : 1.0

            // Optional: when zoomed way out, skip lines so spacing stays >= ~8px on screen
            minPixelSpacing : f32 = 8.0
            stepMul : int = int(math.ceil(minPixelSpacing) / (global_game_texture_grid_cell_size * (camera.zoom > 0 ? camera.zoom : 1.0)))
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


        }


        rl.EndMode2D()

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
    title_centered_pos := [2]f32{global_number_grid_cells_axis_x / 2, 5}
    rlgrid.draw_text_on_grid_centered(gmem.font, "GAME", title_centered_pos, 2, 0, rl.GREEN, global_game_texture_grid_cell_size)
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
