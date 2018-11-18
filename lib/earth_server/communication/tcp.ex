defmodule EarthServer.Communication.TCP do
  use Task

  @behaviour EarthServer.Communication

  # Public API

  @spec announce(port, string) :: any
  def announce(socket, message) do
    Task.start_link(__MODULE__, :_announce, [socket, message])
  end

  @spec announce(port, Regex.t()) :: any
  def listen(socket, validation \\ ~r/.+/) do
    Task.async(__MODULE__, :_listen, [socket, validation]) |> Task.await(100_000)
  end

  def question(socket, text, validation) do
    Task.async(__MODULE__, :_question, [socket, text, validation])
  end

  def listen_many(sockets, validation \\ ~r/.+/) do
    tasks =
      sockets
      |> Enum.map(fn socket ->
        Task.async(fn ->
          _listen(socket, validation)
        end)
      end)

    results = Task.yield_many(tasks, 1_000_000)

    Enum.map(results, fn {_, {:ok, result}} -> result end)
  end

  # Private API

  def _announce(socket, message) do
    :gen_tcp.send(socket, "#{message}\n")
  end

  def _listen(socket, validation) do
    run(socket, validation)
  end

  def run(socket, validation) do
    input = run(socket)

    if Regex.match?(validation, input) do
      input
    else
      _announce(socket, "Input não é valido, tente novamente")
      run(socket, validation)
    end
  end

  def run(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} -> String.replace(data, ~r/\r|\n/, "")
      _ -> nil
    end
  end

  def _question(socket, text, validation) do
    _announce(socket, text)
    _listen(socket, validation)
  end
end
