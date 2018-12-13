defmodule EarthServer do
  require Logger
  alias EarthServer.Game.DefineLeader
  alias EarthServer.Game.LeaderChooses
  alias EarthServer.Game.VotePhase
  alias EarthServer.Game.EvaluationVotes
  alias EarthServer.Game.StartMission
  alias EarthServer.Game.ShuffleCharacters
  alias EarthServer.Game.Ending

  alias EarthServer.Utils.Communication
  @communication Communication.communication()

  def open_port, do: open_port(4641)

  @spec open_port(Integer) :: String
  def open_port(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    start_game(socket, [])
  end

  def start_game(_server_socket, players) when length(players) == 5 do
    game_state = %{
      players: players,
      rounds: [
        # %{
        #   leaderIndex: 2,
        #   soldiers: [2, 1],
        #   soldiersEndorsement: [
        #     %{
        #       player: 3,
        #       vote: "A"
        #     },
        #     %{
        #       player: 4,
        #       vote: "A"
        #     }
        #   ],
        #   mission: %{
        #     votes: [
        #       %{
        #         player: 1,
        #         vote: "S"
        #       },
        #       %{
        #         player: 2,
        #         vote: "S"
        #       }
        #     ]
        #   }
        # }
      ]
    }

    players
    |> ShuffleCharacters.run()
    |> start_round([])
  end

  def start_game(server_socket, players) do
    player_socket = wait_for_player(server_socket)
    start_game(server_socket, [player_socket | players])
  end

  def start_round(players, rounds) when length(rounds) < 5 do
    {players_updated, rounds_updated} =
      players
      |> DefineLeader.run()
      |> LeaderChooses.run()
      |> VotePhase.run()
      |> EvaluationVotes.run()
      |> StartMission.run(rounds)

    start_round(players_updated, rounds_updated)
  end

  def start_round(players, rounds) when length(rounds) == 5 do
    rounds_numbered = Enum.with_index(rounds, 1)

    rounds_numbered
    |> Enum.each(fn {mission_result, index} ->
      @communication.announce_to_many(players, "Rodada #{index} - foi #{mission_result}")
    end)

    successful_rounds = Enum.count(List.flatten(rounds), fn result -> result == "sucesso" end)
    Ending.run(players, successful_rounds)
    close_game()
  end

  def wait_for_player(socket) do
    {:ok, player_socket} = :gen_tcp.accept(socket)

    {:ok, pid} =
      DynamicSupervisor.start_child(
        EarthServer.PlayerConnectionSupervisor,
        {EarthServer.PlayerAgent, player_socket}
      )

    :ok = :gen_tcp.controlling_process(player_socket, pid)
    pid
  end

  def close_game() do
    EarthServer.PlayerConnectionSupervisor |> DynamicSupervisor.stop(:shutdown)
  end

  def enum_tap(items, func) do
    items |> Enum.map(&func.(&1))
    items
  end
end
