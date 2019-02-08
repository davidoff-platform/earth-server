defmodule EarthServer.Game.VotePhase do
  require Logger
  alias EarthServer.PlayerAgent
  alias EarthServer.Utils.Communication

  @communication Communication.communication()

  def run({first, second, players}) do
    Logger.info("Voting phase")

    [_ | voters] = players

    vote_results =
      voters
      |> Enum.map(fn player ->
        socket = player |> PlayerAgent.get(:socket)

        @communication.announce(
          socket,
          "\nO lider escolheu #{first |> PlayerAgent.get(:name)} e #{
            second |> PlayerAgent.get(:name)
          } como soldados \nVote [A] para aceitar ou [R] rejeitar essa escolha: "
        )

        socket
      end)
      |> @communication.listen_many(~r/^[arAR]$/)

    {vote_results, [first, second], players}
  end
end
