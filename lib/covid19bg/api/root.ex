defmodule Covid19bg.API.Root do
  alias Covid19bg.API.Helpers
  alias Covid19bg.Formatters.Text

  @html_header """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Coronavirus Tracker</title>
      <style>
        *, ::after, ::before {
          box-sizing: border-box;
        }
        body {
          background-color: #0d0208;
          color: #00ff41;
          font-size: 1rem;
          font-weight: 400;
          line-height: normal;
          margin: 0;
          text-align: left;
        }
        .container {
          margin-right: auto;
          margin-left: auto;
          padding-right: 10px;
          padding-left: 10px;
          width: 100%;
        }
        pre {
          display: block;
          font-family: SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
          overflow: auto;
          white-space: pre;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <pre>
  """

  @html_footer """
        </pre>
      </div>
    </body>
    </html>
  """

  def get(conn, %{"accept" => "application/json"}) do
    Helpers.send_success(conn, Covid19bg.Source.Arcgis.retrieve() |> Jason.encode!())
  end

  def get(conn, %{"accept" => accept}) do
    with true <- String.contains?(accept, "text/html"),
         "true" <- Map.get(conn.params, "plain", "false") do
      Helpers.send_success(
        conn,
        [
          @html_header,
          Text.format(Covid19bg.Source.Arcgis, false),
          @html_footer
        ],
        "text/html"
      )
    else
      false ->
        send_plain_text(conn)

      "false" ->
        conn
        |> Plug.Conn.put_resp_content_type("text/html")
        |> Plug.Conn.send_file(200, "priv/static/index.html")
    end
  end

  def get(conn, _headers) do
    send_plain_text(conn)
  end

  defp send_plain_text(conn) do
    Helpers.send_success(
      conn,
      Text.format(Covid19bg.Source.Arcgis),
      "text/plain"
    )
  end
end
