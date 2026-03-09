defmodule Apex.GatewayTestHelpers do
  def wait_until(fun, attempts \\ 50, sleep_ms \\ 20)

  def wait_until(fun, attempts, sleep_ms) when is_function(fun, 0) and attempts > 0 do
    if fun.() do
      true
    else
      Process.sleep(sleep_ms)
      wait_until(fun, attempts - 1, sleep_ms)
    end
  end

  def wait_until(_fun, 0, _sleep_ms), do: false
end

ExUnit.start()
