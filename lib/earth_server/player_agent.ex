defmodule EarthServer.PlayerAgent do
  use Agent

  def start_link([name, socket]) do
    Agent.start_link(fn -> EarthServer.Game.Player.new(name, socket) end)
  end

  def get(player_agent) do
    Agent.get(player_agent, fn player -> player end)
  end

  def define_name(player_agent, name) do
    Agent.update(player_agent, fn player ->
      %{player | name: name}
    end)
  end
end
