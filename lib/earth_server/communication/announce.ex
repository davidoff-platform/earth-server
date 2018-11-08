defmodule EarthServer.Communication.Announce do
  use Task

  def start_link(socket, message) do
    Task.start_link(__MODULE__, :announce, [socket, message])
  end

  def announce(socket, message) do
    :gen_tcp.send(socket, "#{message}\n")
  end
end
