defmodule EarthServer.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      {Task.Supervisor, name: EarthServer.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> EarthServer.accept() end}, restart: :permanent)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
