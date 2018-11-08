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

  def open_port, do: open_port(4641)

  @spec open_port(Integer) :: String
  def open_port(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    Logger.info("Accepting connections on port #{port}")
    start_game(socket, [])
  end

  def start_game(_server_socket, players) when length(players) == 5 do
    Logger.info("Starting game")
    rounds = []

    players
    |> shuffle_characters
    |> start_round(rounds)
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

    start_round(players_updated, rounds_updated)
  end

  def start_round(players, rounds) when length(rounds) == 5 do
    rounds_numbered = Enum.with_index(rounds, 1)

    IO.inspect(rounds_numbered: rounds_numbered)

    rounds_numbered
    |> Enum.each(fn {mission_result, index} ->
      players
      |> Enum.each(fn {_, _, player_socket} ->
        announce(player_socket, "Rodada #{index} - foi #{mission_result}")
      end)
    end)

    successful_rounds = Enum.count(List.flatten(rounds), fn result -> result == "sucesso" end)
    ending_game(players, successful_rounds)
  end

  def ending_game(players, successful_rounds) when successful_rounds >= 3 do
    players
    |> Enum.each(fn {_, _, player_socket} ->
      announce(player_socket, "\nO Assassino fará sua jogada final")
    end)

    {_, _, assassin} =
      players
      |> Enum.filter(fn {persona, _, _} -> persona == "Assassin" end)
      |> List.first()

    majority =
      players
      |> Enum.filter(fn {persona, _, _} -> persona != "Minion" || persona != "Assassin" end)

    players_names = extract_players_names(majority)

    announce(
      assassin,
      "\nVocê deve dizer quem é o Merlin: \n#{players_names}"
    )

    {guessed_persona, guessed_merlin_name, _} =
      majority |> Enum.at(String.to_integer(listen(assassin, ~r/[1-3]/)) - 1)

    players
    |> Enum.each(fn {_, _, player_socket} ->
      announce(
        player_socket,
        "\nO Assassino matou o #{guessed_merlin_name} que é #{guessed_persona}"
      )
    end)

    finish_game(players, guessed_persona == "Merlin")
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

  def shuffle_characters(players) do
    personas = ["Merlin", "Loyal", "Loyal", "Assassin", "Minion"]

    Logger.info("Shuffling personas")

    # Mistura e associa personas com jogadores

    names =
      players
      |> Enum.map(fn player ->
        player |> EarthServer.PlayerAgent.socket()
      end)
      |> enum_tap(fn socket ->
        announce(socket, "Qual o seu nome?")
      end)
      |> EarthServer.Communication.Listen.listen_many()

    List.zip([players, personas |> Enum.shuffle(), names])
    |> Enum.map(fn {player, persona, name} ->
      player |> EarthServer.PlayerAgent.persona(persona)
      player |> EarthServer.PlayerAgent.name(name)
    end)

    # -----

    minority =
      players
      |> Enum.filter(fn player ->
        persona = player |> EarthServer.PlayerAgent.persona()
        persona == "Minion" || persona == "Assassin"
      end)

    {_, _, informer} =
      players
      |> Enum.filter(fn player ->
        persona = player |> EarthServer.PlayerAgent.persona()
        persona == "Merlin"
      end)
      |> List.first()

    minority
    |> Enum.map(fn player ->
      announce(
        player |> EarthServer.PlayerAgent.socket(),
        "\nA minoria informada são: #{
          Enum.map(minority, fn player2 -> player2 |> EarthServer.PlayerAgent.name() end)
          |> Enum.join(" - ")
        }"
      )
    end)

    announce(
      informer,
      "\nA minoria informada são: #{
        Enum.map(minority, fn player -> player |> EarthServer.PlayerAgent.name() end)
        |> Enum.join(" - ")
      }"
    )

    players
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
    IO.inspect(players_leader_chooses: players)
    # numero de jogadores igual o contador da rodada

    leader = players |> List.first()

    players
    |> Enum.map(&announce_players_the_leader(&1, leader |> EarthServer.PlayerAgent.name()))

    players
    |> Enum.map(&announce_players_leader_will_choose/1)

    players_available_to_be_soldiers =
      players
      |> Enum.filter(fn {_, _, socket} -> socket != leader end)

    players_names = extract_players_names(players_available_to_be_soldiers)

    announce(
      leader,
      "\nVocê é o líder da rodada. Escolha de 1-4 player: \n#{players_names} "
    )

    first =
      players_available_to_be_soldiers
      |> Enum.at(String.to_integer(listen(leader, ~r/^[1-4]$/)) - 1)

    players_available_to_be_soldiers = players_available_to_be_soldiers |> List.delete(first)

    players_names = extract_players_names(players_available_to_be_soldiers)

    announce(
      leader,
      "\nEscolha de 1-3 player: \n#{players_names} "
    )

    second =
      players_available_to_be_soldiers
      |> Enum.at(String.to_integer(listen(leader, ~r/^[1-3]$/)) - 1)

    {first, second, players}
  end

  def vote_phase({first, second, players}) do
    Logger.info("Voting phase")
    {_, first_name, _} = first
    {_, second_name, _} = second

    [_ | voters] = players

    {voters
     |> Enum.map(fn {_persona, _name, player_socket} -> player_socket end)
     |> enum_tap(fn player_socket ->
       announce(player_socket, "\nO lider escolheu #{first_name} e #{second_name} como soldados")
       announce(player_socket, "\nVote [A] para aceitar ou [R] rejeitar essa escolha: ")
     end)
     |> EarthServer.Communication.Listen.listen_many(~r/^[arAR]$/), [first, second], players}
  end

  def extract_players_names(players) do
    players
    |> Enum.map(fn {_, name, _} -> name end)
    |> Enum.with_index(1)
    |> Enum.map(fn {name, index} ->
      "#{index}. #{name}"
    end)
    |> Enum.join("\n")
  end

  def evaluation_votes({votes, soldiers, players}) do
    [_ | voters] = players
    votes_voters = voters |> Enum.map(fn {_, name, _} -> name end) |> Enum.zip(votes)

    votes_voters
    |> Enum.each(fn {player_name, vote} ->
      players
      |> Enum.each(fn {_persona, _name, player_socket} ->
        announce(player_socket, "O #{player_name} votou #{vote}")
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
    IO.inspect(players)

    players
    |> Enum.map(fn {_persona, _name, player_socket} ->
      announce(player_socket, "\nOs soldados irão para missão, ela terá sucesso?")
    end)

    mission_votes =
      soldiers
      |> Enum.map(fn {_persona, _name, player_socket} ->
        announce(player_socket, "\nVote [S] para sucesso ou [F] para falha")
        listen(player_socket, ~r/^[sfSF]$/)
      end)
      |> Enum.shuffle()

    failed? = Enum.count(mission_votes, fn vote -> String.upcase(vote) == "F" end) > 0
    message = if failed?, do: "falha", else: "sucesso"

    players
    |> Enum.map(fn {_persona, _name, player_socket} ->
      announce(
        player_socket,
        "\nAs cartas foram #{Enum.join(mission_votes, " - ")}, e o resultado foi: #{message}"
      )
    end)

    rounds = [[message] | rounds]
    {players, rounds}
  end

  def start_mission({false, _soldiers, players}, rounds) do
    players
    |> Enum.map(fn {_persona, _name, player_socket} ->
      announce(player_socket, "\nMissão foi cancelada")
    end)

    {players, rounds}
  end

  def announce_players_leader_will_choose({_persona, _name, player_socket}) do
    announce(player_socket, "\nO lider vai escolher seus soldados")
  end

  def announce_players_the_leader({_persona, _name, player_socket}, leader_name) do
    announce(player_socket, "\nO lider da rodada é o #{leader_name}")
  end

  def announce(player_socket, message) do
    EarthServer.Communication.Announce.start_link(player_socket, message)
  end

  def listen(socket, validation) do
    EarthServer.Communication.Listen.listen(socket, validation)
  end

  def finish_game(players, true) do
    players
    |> Enum.each(fn {_, _, player_socket} ->
      announce(player_socket, "A minoria venceu!")
    end)

    finish_game(players)
  end

  def finish_game(players, false) do
    players
    |> Enum.each(fn {_, _, player_socket} ->
      announce(player_socket, "A maioria venceu!")
    end)

    finish_game(players)
  end

  def finish_game(players) do
    players |> Enum.each(fn {_, _, socket} -> :gen_tcp.close(socket) end)
  end
end
