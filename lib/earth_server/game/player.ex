defmodule EarthServer.Game.Player do
  defstruct name: :none,
            socket: :none,
            persona: :none

  def new(socket) do
    %__MODULE__{socket: socket}
  end
end
