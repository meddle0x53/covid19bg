defmodule Covid19bg.API do
  use Plug.Router

  alias Covid19bg.API.{Helpers, Root}

  plug(Plug.Static, at: "/", from: :covid19bg)

  plug(Plug.Logger)
  plug(Plug.Parsers, parsers: [:urlencoded, :multipart, :json, :pass], json_decoder: Jason)
  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> Plug.Conn.fetch_query_params()
    |> Root.get(conn.req_headers |> Enum.into(%{}))
  end

  match _ do
    Helpers.send_error(conn, "Not found!", :not_found)
  end
end
