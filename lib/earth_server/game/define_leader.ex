defmodule EarthServer.Game.DefineLeader do
  require Logger

  def run(game_state) do
    Logger.info("Defining round leader")
    # old_leader = game_state.players |> List.first()
    old_leader = game_state |> List.first()

    game_state =
      game_state
      |> List.insert_at(-1, old_leader)
      |> List.delete_at(0)

    # game_state = %{game_state | players: players_updated}
    game_state
  end
end
