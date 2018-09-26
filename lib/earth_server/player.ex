defmodule EarthServer.Player do
  use Agent

  def start_link(state) do
    IO.inspect(state: state)
    Agent.start_link(fn -> state end)
  end
end
