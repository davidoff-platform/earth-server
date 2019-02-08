defmodule EarthServer.Game.ShuffleCharacters do
  alias EarthServer.PlayerAgent
  alias EarthServer.Utils.Communication

  @communication Communication.communication()

  def run(players) do
    personas = ["Merlin", "Loyal", "Loyal", "Assassin", "Minion"]

    names =
      players
      |> Enum.map(fn player ->
        socket = player |> PlayerAgent.get(:socket)
        @communication.announce(socket, "Qual o seu nome?")
        socket
      end)
      |> @communication.listen_many()

    List.zip([players, personas |> Enum.shuffle(), names])
    |> Enum.map(fn {player, persona, name} ->
      player |> PlayerAgent.update(:persona, persona)
      player |> PlayerAgent.update(:name, name)

      player
      |> PlayerAgent.get(:socket)
      |> @communication.announce("Ola #{name}, voce é o #{persona}")
    end)

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

    @communication.announce_to_many(
      minority,
      "\nA minoria informada são: #{
        Enum.map(minority, fn get_player -> get_player |> PlayerAgent.get(:name) end)
        |> Enum.join(" - ")
      }"
    )

    @communication.announce(
      informer |> PlayerAgent.get(:socket),
      "\nA minoria informada são: #{
        Enum.map(minority, fn player -> player |> PlayerAgent.get(:name) end)
        |> Enum.join(" - ")
      }"
    )

    players
  end
end
