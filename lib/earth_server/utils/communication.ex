defmodule EarthServer.Utils.Communication do
  @spec communication() :: EarthServer.Communication.t()
  def communication do
    Application.get_env(:earth_server, :communication)
  end
end
