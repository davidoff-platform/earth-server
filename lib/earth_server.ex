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
    players
    |> shuffle_characters
    |> start_round
  end

  def start_round(players) do
    players
    |> define_leader
    |> leader_chooses
    |> vote_phase(players)
    |> evaluation_votes
    |> start_mission(players)

    start_round(players)
  end

  def start_game(server_socket, players) do
    player_socket = wait_for_player(server_socket)
    start_game(server_socket, [player_socket | players])
  end

  def wait_for_player(socket) do
    {:ok, player_socket} = :gen_tcp.accept(socket)

    {:ok, pid} =
      DynamicSupervisor.start_child(
        EarthServer.PlayerConnectionSupervisor,
        {EarthServer.Player, %{}}
      )

    :ok = :gen_tcp.controlling_process(player_socket, pid)
    player_socket
  end

  def shuffle_characters(players) do
    personas = ["Merlin", "Loyal", "Loyal", "Assassin", "Minion"]

    List.zip([personas |> Enum.shuffle(), players |> Enum.shuffle()])
    |> Enum.map(fn {persona, player_socket} ->
      announce(player_socket, "Qual o seu nome?")
      {persona, listen(player_socket), player_socket}
    end)
    |> enum_tap(fn {persona, _name, player_socket} ->
      announce(player_socket, "Você é o: #{persona}")
    end)

    # minions devem se conhecer
    # merlin deve conhecer os minions
  end

  def enum_tap(items, func) do
    items |> Enum.map(&func.(&1))
    items
  end

  def define_leader(players) do
    old_leader = players |> List.first()

    IO.inspect(players: players)

    new_players =
      players
      |> List.insert_at(-1, old_leader)
      |> List.delete_at(0)

    IO.inspect(players: players, new_players: new_players)
    new_players
  end

  def leader_chooses(players) do
    # lider diz quais jogadores vao pra missao
    # numero de jogadores igual o contador da rodada
    IO.inspect(players: players)

    players
    |> Enum.map(&announce_players_leader_will_choose/1)

    {_, _, leader_socket} = players |> List.first()

    players_availale_to_be_soldiers =
      players
      |> Enum.filter(fn {_, _, socket} -> socket != leader_socket end)

    players_names =
      players_availale_to_be_soldiers
      |> Enum.map(fn {_, name, _} -> name end)
      |> Enum.with_index(1)
      |> Enum.map(fn {name, index} ->
        "#{index}. #{name}"
      end)
      |> Enum.join("\n")

    announce(
      leader_socket,
      "Escolha de 1-4 player: \n #{players_names} "
    )

    first =
      players_availale_to_be_soldiers |> Enum.at(String.to_integer(listen(leader_socket)) - 1)

    # remover a primeira escolha
    announce(
      leader_socket,
      "Escolha de 1-4 player: \n #{players_names} "
    )

    second =
      players_availale_to_be_soldiers |> Enum.at(String.to_integer(listen(leader_socket)) - 1)

    IO.inspect(first: first)
    IO.inspect(second: second)

    {first, second}
  end

  def vote_phase({first, second}, players) do
    {_, first_name, _} = first
    {_, second_name, _} = second

    {players
     |> Enum.map(fn {_persona, _name, player_socket} ->
       announce(player_socket, "O lider escolheu #{first_name} e #{second_name} como soldados")
       announce(player_socket, "Vote [S] para aceitar ou [N] rejeitar essa escolha: ")
       listen(player_socket)
     end), [first, second]}
  end

  def evaluation_votes({votes, soldiers}) do
    IO.inspect(votes: votes, soldiers: soldiers)

    {
      Enum.count(votes, fn vote -> vote == "S" end) >= 3,
      soldiers
    }
  end

  def start_mission({true, soldiers}, players) do
    players
    |> Enum.map(fn {_persona, _name, player_socket} ->
      announce(player_socket, "Os soldados iram para missão, ela terá sucesso?")
    end)

    soldiers
    |> Enum.map(fn {_persona, _name, player_socket} ->
      announce(player_socket, "Vote [S] para sucesso ou [F] para falha")
      listen(player_socket)
    end)
  end

  def start_mission({false, soldiers}, players) do
    players
    |> Enum.map(fn {_persona, _name, player_socket} ->
      announce(player_socket, "Missão foi cancelada")
    end)

    :failed
  end

  def announce_players_leader_will_choose({_persona, _name, player_socket}) do
    announce(player_socket, "O lider vai escolher seus soldados")
  end

  def announce(player_socket, message) do
    :gen_tcp.send(player_socket, "#{message}\n")
  end

  def listen(player_socket) do
    {:ok, data} = :gen_tcp.recv(player_socket, 0)
    String.replace(data, ~r/\r|\n/, "")
  end

  def finish_game do
  end
end
