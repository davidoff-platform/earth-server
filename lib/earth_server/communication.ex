defmodule EarthServer.Communication do
  @callback announce(target :: any, text :: string) :: any
  @callback question(target :: any, text :: string, validation :: Regex.t()) :: any
  @callback listen(target :: any, validation :: Regex.t()) :: any
  @callback listen(target :: any) :: any
end
