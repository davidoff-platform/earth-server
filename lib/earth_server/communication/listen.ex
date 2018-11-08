defmodule EarthServer.Communication.Listen do
  use Task

  # Public API

  def listen_many(sockets, validation \\ ~r/.+/) do
    tasks =
      sockets
      |> Enum.map(fn socket ->
        Task.async(fn ->
          EarthServer.Communication.Listen.listen(socket, validation)
        end)
      end)

    results = Task.yield_many(tasks, 1_000_000)

    IO.inspect(results)

    Enum.map(results, fn {_, {:ok, result}} -> result end)
  end

  # -----

  def listen(socket, validation) do
    async(socket, validation) |> Task.await(100_000)
  end

  # Private API

  def async(socket, validation) do
    Task.async(__MODULE__, :run, [socket, validation])
  end

  def run(socket, validation) do
    input = run(socket)

    if Regex.match?(validation, input) do
      input
    else
      EarthServer.Communication.Announce.start_link(socket, "Input não é valido, tente novamente")
      run(socket, validation)
    end
  end

  def run(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} -> String.replace(data, ~r/\r|\n/, "")
      _ -> nil
    end
  end
end
