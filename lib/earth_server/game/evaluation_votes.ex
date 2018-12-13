defmodule EarthServer.Game.EvaluationVotes do
  alias EarthServer.PlayerAgent
  alias EarthServer.Utils.Communication

  @communication Communication.communication()

  def run({votes, soldiers, players}) do
    [_ | voters] = players

    votes_voters =
      voters
      |> Enum.map(fn player -> player |> PlayerAgent.get(:name) end)
      |> Enum.zip(votes)

    votes_voters
    |> Enum.each(fn {player_name, vote} ->
      @communication.announce_to_many(players, "O #{player_name} votou #{vote}")
    end)

    {
      Enum.count(votes, fn vote -> String.upcase(vote) == "A" end) >= 3,
      soldiers,
      players
    }
  end
end
