package main

import game ".."
import rl "vendor:raylib"


main :: proc() 
{

    game.game_init_platform()
    game.game_init()

    for game.game_should_run() 
    {
        game.game_update()
    }

    game.game_shutdown()
}
