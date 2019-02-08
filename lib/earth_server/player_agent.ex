defmodule EarthServer.PlayerAgent do
  use Agent

  def start_link(socket) do
    Agent.start_link(fn -> %{socket: socket} end)
  end

  def update(pid, key, value) do
    Agent.update(pid, &Map.put(&1, key, value))
  end

  def get(pid, key) do
    Agent.get(pid, &Map.fetch!(&1, key))
  end
end
