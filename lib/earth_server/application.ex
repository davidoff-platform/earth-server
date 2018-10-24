defmodule EarthServer.Application do
  use Application

  def start(_type, _args) do
    # :observer.start()

    EarthServer.Supervisor.start_link([])
  end
end
