defmodule Apex.Gateway.Router do
  use Plug.Router
  use Plug.ErrorHandler

  import Plug.Conn

  plug :put_cors_headers
  plug Plug.Logger
  plug :match

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason

  plug :dispatch

  def render(term), do: do_render(term)

  options _ do
    send_resp(conn, 204, "")
  end

  get "/healthz" do
    send_json(conn, 200, %{status: "ok"})
  end

  get "/openapi.yaml" do
    path = Application.app_dir(:gateway, "priv/openapi.yaml")
    conn
    |> put_resp_content_type("application/yaml")
    |> send_file(200, path)
  end

  get "/capabilities" do
    send_json(conn, 200, %{data: render(Apex.Runtime.list_capabilities())})
  end

  get "/capabilities/:name" do
    case Apex.Runtime.get_capability(name) do
      nil -> send_error(conn, 404, %{message: "capability not found"})
      capability -> send_json(conn, 200, %{data: render(capability)})
    end
  end

  get "/executions" do
    send_json(conn, 200, %{data: render(Apex.Runtime.list_executions())})
  end

  post "/executions" do
    case Apex.Runtime.request_execution(conn.body_params) do
      {:ok, execution} ->
        send_json(conn, 201, %{data: render(execution)})

      {:error, error} ->
        send_error(conn, 400, error)
    end
  end

  get "/executions/:id" do
    case Apex.Runtime.get_execution(id) do
      nil -> send_error(conn, 404, %{message: "execution not found"})
      execution -> send_json(conn, 200, %{data: render(execution)})
    end
  end

  get "/approvals" do
    send_json(conn, 200, %{data: render(Apex.Runtime.list_approvals())})
  end

  post "/approvals/:id/approve" do
    approved_by = Map.get(conn.body_params, "approved_by", "operator")

    case Apex.Runtime.approve(id, approved_by) do
      {:ok, approval} ->
        send_json(conn, 200, %{data: render(approval)})

      {:error, :not_found} ->
        send_error(conn, 404, %{message: "approval not found"})

      {:error, reason} ->
        send_error(conn, 400, %{message: inspect(reason)})
    end
  end

  post "/approvals/:id/deny" do
    denied_by = Map.get(conn.body_params, "denied_by", "operator")
    reason = Map.get(conn.body_params, "reason")

    case Apex.Runtime.deny(id, denied_by, reason) do
      {:ok, approval} ->
        send_json(conn, 200, %{data: render(approval)})

      {:error, :not_found} ->
        send_error(conn, 404, %{message: "approval not found"})

      {:error, reason} ->
        send_error(conn, 400, %{message: inspect(reason)})
    end
  end

  get "/resources" do
    send_json(conn, 200, %{data: render(Apex.Runtime.list_resources())})
  end

  get "/events" do
    filters =
      conn.query_params
      |> Map.take(["type", "workspace_id", "entity_id"])

    send_json(conn, 200, %{data: render(Apex.Runtime.list_events(filters))})
  end

  get "/events/stream" do
    Apex.Gateway.SSE.stream(conn)
  end

  match _ do
    send_error(conn, 404, %{message: "route not found"})
  end

  @impl Plug.ErrorHandler
  def handle_errors(conn, %{reason: reason}) do
    send_error(conn, conn.status || 500, %{message: inspect(reason)})
  end

  defp send_json(conn, status, payload) do
    body = Jason.encode!(payload)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
  end

  defp send_error(conn, status, error) do
    send_json(conn, status, %{error: render(error)})
  end

  defp do_render(term) when is_list(term), do: Enum.map(term, &do_render/1)
  defp do_render(term) when is_pid(term), do: inspect(term)
  defp do_render(term) when is_tuple(term), do: term |> Tuple.to_list() |> Enum.map(&do_render/1)

  defp do_render(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:handler])
    |> Enum.into(%{}, fn {key, value} ->
      key_string = Atom.to_string(key)
      {key_string, render_value(key_string, value)}
    end)
  end

  defp do_render(map) when is_map(map) do
    Enum.into(map, %{}, fn {key, value} ->
      key_string = if is_atom(key), do: Atom.to_string(key), else: to_string(key)
      {key_string, render_value(key_string, value)}
    end)
  end

  defp do_render(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp do_render(other), do: other

  defp render_value(key, value) when key in ["effect_type", "approval_requirement", "state", "decision", "status", "mode", "from", "to"] and is_atom(value) do
    value |> Atom.to_string() |> String.upcase()
  end

  defp render_value(_key, value) when is_pid(value), do: inspect(value)
  defp render_value(_key, value), do: do_render(value)

  defp put_cors_headers(conn, _opts) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET,POST,OPTIONS")
    |> put_resp_header("access-control-allow-headers", "content-type,authorization")
  end
end
