defmodule EarthServer.Game.LeaderChooses do
  require Logger
  alias EarthServer.PlayerAgent
  alias EarthServer.Utils.Communication
  alias EarthServer.Utils.GameHelper

  @communication Communication.communication()

  def run(players) do
    Logger.info("Leader chooses")

    leader = players |> List.first()

    @communication.announce_to_many(
      players,
      "\nO lider da rodada é o #{leader |> PlayerAgent.get(:name)}"
    )

    @communication.announce_to_many(players, "\nO líder vai escolher seus soldados")

    players_names = GameHelper.extract_players_names(players)

    @communication.announce(
      leader |> PlayerAgent.get(:socket),
      "\nVocê é o líder da rodada. Escolha o player de 1-5: \n#{players_names} "
    )

    first =
      players
      |> Enum.at(
        String.to_integer(@communication.listen(leader |> PlayerAgent.get(:socket), ~r/^[1-5]$/)) -
          1
      )

    players_available_to_be_soldiers = players |> List.delete(first)

    players_names = GameHelper.extract_players_names(players_available_to_be_soldiers)

    @communication.announce(
      leader |> PlayerAgent.get(:socket),
      "\nEscolha o player de 1-4: \n#{players_names} "
    )

    second =
      players_available_to_be_soldiers
      |> Enum.at(
        String.to_integer(@communication.listen(leader |> PlayerAgent.get(:socket), ~r/^[1-4]$/)) -
          1
      )

    {first, second, players}
  end
end
