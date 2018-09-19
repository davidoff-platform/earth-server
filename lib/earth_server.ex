defmodule EarthServer do
  require Logger

  def accept, do: accept(4641)

  @spec accept(Integer) :: String
  def accept(port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    Logger.info("Accepting connections on port #{port}")
    loop_acceptor(socket)
  end

  def loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} =
      Task.Supervisor.start_child(EarthServer.TaskSupervisor, fn ->
        serve(client)
      end)

    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  def serve(socket) do
    socket |> read_line() |> write_line(socket)
    serve(socket)
  end

  def read_line(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    Logger.debug("line: #{data}")
    data
  end

  def write_line(line, socket) do
    :gen_tcp.send(socket, line)
  end
end
