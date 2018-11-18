# Server
# - Announcements
# - User Input
# - Socket Connection (Server Players)
#
# Game
# - Game Rules
# - Game Engine
# - Player
#
# Infra
# - Test
# - Deploy
# - Logger
defmodule EarthServer do
  require Logger

  alias EarthServer.PlayerAgent

  @spec communication() :: EarthServer.Communication.t()
  def communication do
    Application.get_env(:earth_server, :communication)
  end

  def open_port, do: open_port(4641)

  @spec open_port(Integer) :: String
  def open_port(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    start_game(socket, [])
  end

  def start_game(_server_socket, players) when length(players) == 5 do
    Logger.info("Starting game")

    players
    |> shuffle_characters
    |> start_round([])
  end

  def start_game(server_socket, players) do
    player_socket = wait_for_player(server_socket)
    start_game(server_socket, [player_socket | players])
  end

  def start_round(players, rounds) when length(rounds) < 5 do
    {players_updated, rounds_updated} =
      players
      |> define_leader
      |> leader_chooses
      |> vote_phase
      |> evaluation_votes
      |> start_mission(rounds)

    IO.inspect(rounds_updated: rounds_updated)
    Logger.info("começando nova rodada de numero #{length(rounds_updated)}")
    start_round(players_updated, rounds_updated)
  end

  def start_round(players, rounds) when length(rounds) == 5 do
    rounds_numbered = Enum.with_index(rounds, 1)

    IO.inspect(rounds: rounds)
    IO.inspect(rounds_numbered: rounds_numbered)

    rounds_numbered
    |> Enum.each(fn {mission_result, index} ->
      players
      |> Enum.each(fn player ->
        announce(
          player |> PlayerAgent.get(:socket),
          "Rodada #{index} - foi #{mission_result}"
        )
      end)
    end)

    successful_rounds = Enum.count(List.flatten(rounds), fn result -> result == "sucesso" end)
    ending_game(players, successful_rounds)
  end

  def shuffle_characters(players) do
    personas = ["Merlin", "Loyal", "Loyal", "Assassin", "Minion"]

    names =
      players
      |> Enum.map(fn player ->
        socket = player |> PlayerAgent.get(:socket)
        communication().announce(socket, "Qual o seu nome?")
        socket
      end)
      |> communication().listen_many()

    List.zip([players, personas |> Enum.shuffle(), names])
    |> Enum.map(fn {player, persona, name} ->
      player |> PlayerAgent.update(:persona, persona)
      player |> PlayerAgent.update(:name, name)

      player
      |> PlayerAgent.get(:socket)
      |> communication().announce("Ola #{name}, voce é o #{persona}")
    end)

    # -----

    minority =
      players
      |> Enum.filter(fn player ->
        persona = player |> PlayerAgent.get(:persona)
        persona == "Minion" || persona == "Assassin"
      end)

    informer =
      players
      |> Enum.filter(fn player ->
        player |> PlayerAgent.get(:persona) == "Merlin"
      end)
      |> List.first()

    minority
    |> Enum.map(fn player ->
      announce(
        player |> PlayerAgent.get(:socket),
        "\nA minoria informada são: #{
          Enum.map(minority, fn get_player -> get_player |> PlayerAgent.get(:name) end)
          |> Enum.join(" - ")
        }"
      )
    end)

    announce(
      informer |> PlayerAgent.get(:socket),
      "\nA minoria informada são: #{
        Enum.map(minority, fn player -> player |> PlayerAgent.get(:name) end)
        |> Enum.join(" - ")
      }"
    )

    players
  end

  def ending_game(players, successful_rounds) when successful_rounds >= 3 do
    players
    |> Enum.each(fn player ->
      announce(
        player |> PlayerAgent.get(:socket),
        "\nO Assassino fará sua jogada final"
      )
    end)

    assassin =
      players
      |> Enum.filter(fn player -> player |> PlayerAgent.get(:persona) == "Assassin" end)
      |> List.first()

    majority =
      players
      |> Enum.filter(fn player ->
        persona = player |> PlayerAgent.get(:persona)
        persona != "Minion" || persona != "Assassin"
      end)

    players_names = extract_players_names(majority)

    announce(
      assassin |> PlayerAgent.get(:socket),
      "\nVocê deve dizer quem é o Merlin: \n#{players_names}"
    )

    guessed =
      majority
      |> Enum.at(String.to_integer(listen(assassin |> PlayerAgent.get(:socket), ~r/[1-3]/)) - 1)

    players
    |> Enum.each(fn player ->
      announce(
        player |> PlayerAgent.get(:socket),
        "\nO Assassino matou o #{PlayerAgent.get(guessed, :name)} que é #{
          PlayerAgent.get(guessed, :persona)
        }"
      )
    end)

    finish_game(players, PlayerAgent.get(guessed, :persona) == "Merlin")
  end

  def ending_game(players, _) do
    finish_game(players, true)
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

  def enum_tap(items, func) do
    items |> Enum.map(&func.(&1))
    items
  end

  def define_leader(players) do
    Logger.info("Defining round leader")
    old_leader = players |> List.first()

    players_updated =
      players
      |> List.insert_at(-1, old_leader)
      |> List.delete_at(0)

    players_updated
  end

  def leader_chooses(players) do
    Logger.info("Leader chooses")

    leader = players |> List.first()

    players
    |> Enum.map(fn player ->
      announce(
        player |> PlayerAgent.get(:socket),
        "\nO lider da rodada é o #{leader |> PlayerAgent.get(:name)}"
      )
    end)

    players
    |> Enum.map(fn player ->
      announce(
        player |> PlayerAgent.get(:socket),
        "\nO lider vai escolher seus soldados"
      )
    end)

    players_names = extract_players_names(players)

    announce(
      leader |> PlayerAgent.get(:socket),
      "\nVocê é o líder da rodada. Escolha o player de 1-5: \n#{players_names} "
    )

    first =
      players
      |> Enum.at(String.to_integer(listen(leader |> PlayerAgent.get(:socket), ~r/^[1-5]$/)) - 1)

    players_available_to_be_soldiers = players |> List.delete(first)

    players_names = extract_players_names(players_available_to_be_soldiers)

    announce(
      leader |> PlayerAgent.get(:socket),
      "\nEscolha o player de 1-4: \n#{players_names} "
    )

    second =
      players_available_to_be_soldiers
      |> Enum.at(String.to_integer(listen(leader |> PlayerAgent.get(:socket), ~r/^[1-4]$/)) - 1)

    {first, second, players}
  end

  def vote_phase({first, second, players}) do
    Logger.info("Voting phase")

    [_ | voters] = players

    vote_results =
      voters
      |> Enum.map(fn player ->
        socket = player |> PlayerAgent.get(:socket)

        announce(
          socket,
          "\nO lider escolheu #{first |> PlayerAgent.get(:name)} e #{
            second |> PlayerAgent.get(:name)
          } como soldados"
        )

        announce(
          socket,
          "\nVote [A] para aceitar ou [R] rejeitar essa escolha: "
        )

        socket
      end)
      |> communication().listen_many(~r/^[arAR]$/)

    IO.inspect(vote_results: vote_results)
    {vote_results, [first, second], players}
  end

  def evaluation_votes({votes, soldiers, players}) do
    [_ | voters] = players

    votes_voters =
      voters
      |> Enum.map(fn player -> player |> PlayerAgent.get(:name) end)
      |> Enum.zip(votes)

    votes_voters
    |> Enum.each(fn {player_name, vote} ->
      players
      |> Enum.each(fn player ->
        announce(
          player |> PlayerAgent.get(:socket),
          "O #{player_name} votou #{vote}"
        )
      end)
    end)

    {
      Enum.count(votes, fn vote -> String.upcase(vote) == "A" end) >= 3,
      soldiers,
      players
    }
  end

  def start_mission({true, soldiers, players}, rounds) do
    Logger.info("Mission will start")

    players
    |> Enum.map(fn player ->
      announce(
        player |> PlayerAgent.get(:socket),
        "\nOs soldados irão para missão, ela terá sucesso?"
      )
    end)

    mission_votes =
      soldiers
      |> Enum.map(fn player -> player |> PlayerAgent.get(:socket) end)
      |> enum_tap(fn p ->
        communication().announce(p, "\nVote [S] para sucesso ou [F] para falha")
      end)
      |> communication().listen_many(~r/^[sfSF]$/)
      |> Enum.shuffle()

    failed? = Enum.count(mission_votes, fn vote -> String.upcase(vote) == "F" end) > 0
    message = if failed?, do: "falha", else: "sucesso"

    players
    |> Enum.map(fn player ->
      announce(
        player |> PlayerAgent.get(:socket),
        "\nAs cartas foram #{Enum.join(mission_votes, " - ")}, e o resultado foi: #{message}"
      )
    end)

    rounds = rounds ++ [message]
    {players, rounds}
  end

  def start_mission({false, _soldiers, players}, rounds) do
    players
    |> Enum.map(fn player ->
      announce(player |> PlayerAgent.get(:socket), "\nMissão foi cancelada")
    end)

    {players, rounds}
  end

  def finish_game(players, true) do
    players
    |> Enum.each(fn player ->
      announce(player |> PlayerAgent.get(:socket), "A minoria venceu!")
    end)

    finish_game(players)
  end

  def finish_game(players, false) do
    players
    |> Enum.each(fn player ->
      announce(player |> PlayerAgent.get(:socket), "A maioria venceu!")
    end)

    finish_game(players)
  end

  def finish_game(_players) do
    EarthServer.PlayerConnectionSupervisor |> DynamicSupervisor.stop(:shutdown)
  end

  def extract_players_names(players) do
    players
    |> Enum.map(fn player -> player |> PlayerAgent.get(:name) end)
    |> Enum.with_index(1)
    |> Enum.map(fn {name, index} ->
      "#{index}. #{name}"
    end)
    |> Enum.join("\n")
  end

  def announce(player_socket, message) do
    communication().announce(player_socket, message)
  end

  def listen(socket, validation) do
    communication().listen(socket, validation)
  end
end
