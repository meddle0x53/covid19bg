defmodule Covid19bg.API.Helpers do
  alias Plug.Conn

  @default_content_type "application/json"

  def send_success(conn, message, content_type \\ @default_content_type, code \\ :ok) do
    conn
    |> Conn.put_resp_content_type(content_type)
    |> Conn.send_resp(code, message)
  end

  def send_error(conn, message \\ "Internal Server Error", code \\ :internal_server_error) do
    conn
    |> Conn.put_resp_content_type(@default_content_type)
    |> Conn.send_resp(code, Jason.encode!(%{error: %{message: message}}))
  end
end
