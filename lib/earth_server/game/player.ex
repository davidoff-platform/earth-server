defmodule EarthServer.Game.Player do
  defstruct name: :none,
            socket: :none

  def new(name, socket) do
    %__MODULE__{name: name, socket: socket}
  end
end
