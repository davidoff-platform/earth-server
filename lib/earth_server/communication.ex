defmodule EarthServer.Communication do
  @callback announce(target :: any, text :: String.t()) :: any
  @callback question(target :: any, text :: String.t(), validation :: Regex.t()) :: any
  @callback listen(target :: any, validation :: Regex.t()) :: any
  @callback listen(target :: any) :: any
  @callback announce_to_many(target_list :: List, text :: String.t()) :: any
end
