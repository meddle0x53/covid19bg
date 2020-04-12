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
    data = get_source(conn).retrieve()
    cases_by_location = Map.get(data, :casesByLocation)

    cases_by_location_json =
      cases_by_location
      |> Enum.map(&Map.from_struct/1)

    Helpers.send_success(
      conn,
      %{data | casesByLocation: cases_by_location_json} |> Jason.encode!()
    )
  end

  def get(conn, %{"accept" => accept}) do
    with true <- String.contains?(accept, "text/html"),
         "true" <- Map.get(conn.params, "plain", "false") do
      Helpers.send_success(
        conn,
        [
          @html_header,
          Text.format(get_source(conn), false),
          @html_footer
        ],
        "text/html"
      )
    else
      false ->
        send_plain_text(conn)

      "false" ->
        index_file =
          :code.priv_dir(:covid19bg)
          |> to_string()
          |> Path.join("static")
          |> Path.join("index.html")
          |> IO.inspect()

        conn
        |> Plug.Conn.put_resp_content_type("text/html")
        |> Plug.Conn.send_file(200, index_file)
    end
  end

  def get(conn, _headers) do
    send_plain_text(conn)
  end

  defp send_plain_text(conn) do
    Helpers.send_success(
      conn,
      Text.format(get_source(conn)),
      "text/plain"
    )
  end

  defp get_source(conn) do
    case Map.get(conn.params, "source", "local") do
      "arcgis" -> Covid19bg.Source.Arcgis
      "nsi" -> Covid19bg.Source.Arcgis
      "local" -> Covid19bg.Source.LocalBg
      "snify" -> Covid19bg.Source.SnifyCovidOpendataBulgaria
    end
  end
end
