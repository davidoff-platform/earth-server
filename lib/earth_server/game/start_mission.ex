defmodule EarthServer.Game.StartMission do
  alias EarthServer.PlayerAgent
  alias EarthServer.Utils.Communication

  @communication Communication.communication()

  def run({true, soldiers, players}, rounds) do
    @communication.announce_to_many(
      players,
      "\nOs soldados irão para missão, ela terá sucesso?"
    )

    mission_votes =
      soldiers
      |> Enum.map(fn player -> player |> PlayerAgent.get(:socket) end)
      |> enum_tap(fn p ->
        @communication.announce(p, "\nVote [S] para sucesso ou [F] para falha")
      end)
      |> @communication.listen_many(~r/^[sfSF]$/)
      |> Enum.shuffle()

    failed? = Enum.count(mission_votes, fn vote -> String.upcase(vote) == "F" end) > 0
    message = if failed?, do: "falha", else: "sucesso"

    @communication.announce_to_many(
      players,
      "\nAs cartas foram #{Enum.join(mission_votes, " - ")}, e o resultado foi: #{message}"
    )

    rounds = rounds ++ [message]
    {players, rounds}
  end

  def run({false, _soldiers, players}, rounds) do
    @communication.announce_to_many(players, "\nMissão foi cancelada")

    {players, rounds}
  end

  def enum_tap(items, func) do
    items |> Enum.map(&func.(&1))
    items
  end
end
