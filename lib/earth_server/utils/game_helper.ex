defmodule EarthServer.Utils.GameHelper do
  alias EarthServer.PlayerAgent

  def extract_players_names(players) do
    players
    |> Enum.map(fn player -> player |> PlayerAgent.get(:name) end)
    |> Enum.with_index(1)
    |> Enum.map(fn {name, index} ->
      "#{index}. #{name}"
    end)
    |> Enum.join("\n")
  end
end
