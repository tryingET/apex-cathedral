defmodule Apex.Gateway.SSE do
  import Plug.Conn

  def stream(conn) do
    conn =
      conn
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("x-accel-buffering", "no")
      |> put_resp_content_type("text/event-stream")
      |> send_chunked(200)

    Apex.Runtime.subscribe_events()
    {:ok, conn} = chunk(conn, "event: ready\ndata: {\"status\":\"connected\"}\n\n")
    loop(conn)
  end

  defp loop(conn) do
    receive do
      {:audit_event, event} ->
        payload = Jason.encode!(Apex.Gateway.Router.render(event))

        case chunk(conn, "event: audit\ndata: " <> payload <> "\n\n") do
          {:ok, conn} -> loop(conn)
          {:error, :closed} -> conn
        end
    after
      15_000 ->
        case chunk(conn, ": keep-alive\n\n") do
          {:ok, conn} -> loop(conn)
          {:error, :closed} -> conn
        end
    end
  end
end
