package main

import "core:c/libc"
import "core:dynlib"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:os/os2"

Game_API :: struct 
{
    // library
    lib :                dynlib.Library,
    modification_time :  os.File_Time,
    api_version :        int,

    // api
    init_platform :      proc(),
    init :               proc(),
    update :             proc(),
    should_run :         proc() -> bool,
    memory_ptr :         proc() -> rawptr,
    memory_size :        proc() -> int,
    hot_reload :         proc(mem : rawptr),
    is_build_requested : proc() -> bool,
    shutdown :           proc(),
    free_memory :        proc(),
}


when ODIN_OS == .Windows 
{
    DLL_EXT :: ".dll"
    BUILD_HOT_RELOAD_SCRIPT :: "build_hot_reload.bat"
}
 else when ODIN_OS == .Darwin 
{
    DLL_EXT :: ".dylib"
    BUILD_HOT_RELOAD_SCRIPT :: "build_hot_reload.sh"
}
 else 
{
    DLL_EXT :: ".so"
    BUILD_HOT_RELOAD_SCRIPT :: "build_hot_reload.sh"
}


GAME_DLL_DIR :: "build/hot_reload/"
GAME_DLL_PATH :: GAME_DLL_DIR + "game" + DLL_EXT


load_game_api :: proc(api_version : int) -> (api : Game_API, ok : bool) 
{
    modification_time, get_modification_time_error := os.last_write_time_by_name(GAME_DLL_PATH)
    if get_modification_time_error != os.ERROR_NONE 
    {
        fmt.printfln("Failed getting last write time of " + GAME_DLL_PATH + ", error code: {1}", get_modification_time_error)
        return
    }

    game_dll_name := fmt.tprintf(GAME_DLL_DIR + "game_{0}" + DLL_EXT, api_version)

    copy_err := os2.copy_file(game_dll_name, GAME_DLL_PATH)

    if copy_err != nil 
    {
        fmt.printfln("Failed to copy " + GAME_DLL_PATH + " to {0}: %v", game_dll_name, copy_err)
        return
    }

    _, is_dynlib_initialize_symbols_ok := dynlib.initialize_symbols(&api, game_dll_name, "game_", "lib")
    if !is_dynlib_initialize_symbols_ok 
    {
        dynlib_error := dynlib.last_error()
        fmt.printfln("Failed initializing symbols: {0}", dynlib_error)
    }

    api.api_version = api_version
    api.modification_time = modification_time
    ok = true

    return
}


unload_game_api :: proc(api : ^Game_API) 
{
    is_library_loaded := api.lib != nil
    if is_library_loaded 
    {
        is_unload_ok := dynlib.unload_library(api.lib)

        if is_unload_ok 
        {
            dynlib_error := dynlib.last_error()
            fmt.printfln("Failed unloading lib: {0}", dynlib_error)
        }
    }

    game_dll_path_with_version := fmt.tprintf(GAME_DLL_DIR + "game_{0}" + DLL_EXT, api.api_version)
    remove_error := os.remove(game_dll_path_with_version)
    if remove_error != nil 
    {
        fmt.printfln("Failed to remove %v", game_dll_path_with_version)
    }
}


main :: proc() 
{
    context.logger = log.create_console_logger()

    when ODIN_DEBUG     
    {
        track : mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer 


        
        {
            if len(track.allocation_map) > 0 
            {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map 
                {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
            // libc.getchar()
        }
    }

    game_api, game_api_loaded_ok := load_game_api(0)

    if !game_api_loaded_ok 
    {
        fmt.printfln("Failed to load game api")
        return
    }

    game_api.init_platform()
    game_api.init()

    old_game_apis := make([dynamic]Game_API)

    for game_api.should_run() 
    {
        game_api.update()

        is_build_requested := game_api.is_build_requested()

        if is_build_requested 
        {
            process_desc := os2.Process_Desc \
            {
                command = []string{BUILD_HOT_RELOAD_SCRIPT},
            }

            // NOTE(jblat): If we make this non-blocking in the future, then must use different allocator than temp allocator
            // just setting it to temp allocator so it gets reset after next frame
            _, stdout, stderr, _ := os2.process_exec(process_desc, allocator = context.temp_allocator)
            if stdout != nil 
            {
                fmt.printf("%s", stdout)
            }
            if stderr != nil 
            {
                fmt.printf("%s", stderr)
            }
        }


        game_dll_modification_time, get_modification_time_error := os.last_write_time_by_name(GAME_DLL_PATH)

        is_there_error_getting_modification_time := get_modification_time_error != os.ERROR_NONE

        if is_there_error_getting_modification_time 
        {
            fmt.printfln("Error checking modification time: %v", get_modification_time_error)
        }

        game_dll_modification_time_different := game_dll_modification_time != game_api.modification_time

        should_reload := game_dll_modification_time_different && !is_there_error_getting_modification_time

        if should_reload 
        {
            new_game_api, new_game_api_loaded_ok := load_game_api(game_api.api_version + 1)

            if new_game_api_loaded_ok 
            {
                game_memory_struct_size_changed := game_api.memory_size() != new_game_api.memory_size()
                should_restart_app := game_memory_struct_size_changed

                if should_restart_app 
                {
                    game_api.free_memory()

                    for &g in old_game_apis 
                    {
                        unload_game_api(&g)
                    }

                    clear(&old_game_apis)
                    unload_game_api(&game_api)
                    game_api = new_game_api
                    game_api.init()
                }
                 else 
                {
                    append(&old_game_apis, game_api)
                    game_memory := game_api.memory_ptr()
                    game_api = new_game_api
                    game_api.hot_reload(game_memory)
                }
            }
             else 
            {
                fmt.printfln("Game API load failed")
            }
        }

        free_all(context.temp_allocator)
    }

    game_api.shutdown()
}
