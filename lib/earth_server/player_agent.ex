defmodule EarthServer.PlayerAgent do
  use Agent

  def start_link(socket) do
    Agent.start_link(fn -> %{socket: socket} end)
  end

  # ----

  # def socket(%Map{} = pid) do
  #   player.socket
  # end

  def socket(pid) do
    Agent.get(pid, fn player -> player.socket end)
  end

  def name(pid) do
    Agent.get(pid, fn player -> player.name end)
  end

  def name(pid, name) do
    Agent.update(pid, fn player ->
      EarthServer.Communication.Announce.start_link(player.socket, "Ola #{name}")
      Map.put(player, :name, name)
    end)
  end

  def persona(pid, persona) do
    Agent.update(pid, fn player ->
      EarthServer.Communication.Announce.start_link(
        player.socket,
        "Seu personagem é o: #{persona}"
      )

      Map.put(player, :persona, persona)
    end)
  end
end
