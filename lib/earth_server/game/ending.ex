defmodule EarthServer.Game.Ending do
  alias EarthServer.PlayerAgent
  alias EarthServer.Utils.Communication
  alias EarthServer.Utils.GameHelper

  @communication Communication.communication()

  def run(players, successful_rounds) when successful_rounds >= 3 do
    @communication.announce_to_many(
      players,
      "\nO Assassino fará sua jogada final"
    )

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

    players_names = GameHelper.extract_players_names(majority)

    @communication.announce(
      assassin |> PlayerAgent.get(:socket),
      "\nVocê deve dizer quem é o Merlin: \n#{players_names}"
    )

    guessed =
      majority
      |> Enum.at(
        String.to_integer(@communication.listen(assassin |> PlayerAgent.get(:socket), ~r/[1-3]/)) -
          1
      )

    @communication.announce_to_many(
      players,
      "\nO Assassino matou o #{PlayerAgent.get(guessed, :name)} que é #{
        PlayerAgent.get(guessed, :persona)
      }"
    )

    finish_game(players, PlayerAgent.get(guessed, :persona) == "Merlin")
  end

  def finish_game(players, minority_wins) do
    cond do
      minority_wins == true -> @communication.announce_to_many(players, "A minoria venceu!")
      minority_wins == false -> @communication.announce_to_many(players, "A maioria venceu!")
    end
  end
end
