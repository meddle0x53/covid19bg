defmodule Covid19bg.API.Root do
  alias Covid19bg.API.{Helpers, Params}
  alias Covid19bg.Formatters.Text
  alias Covid19bg.Source.LocationData

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
    params = build_params(conn)
    data = params.source.retrieve(params.data_type, params.location)

    cases =
      data
      |> LocationData.sort_and_rank(params.order_keys)
      |> (fn list ->
            if params.order_direction == :ask do
              Enum.reverse(list)
            else
              list
            end
          end).()
      |> Enum.map(&Map.from_struct/1)
      |> Enum.drop(params.offset)
      |> Enum.take(params.limit)

    Helpers.send_success(
      conn,
      cases |> Jason.encode!()
    )
  end

  def get(conn, %{"accept" => accept}) do
    with true <- String.contains?(accept, "text/html"),
         "true" <- Map.get(conn.params, "plain", "false") do
      params = build_params(conn)

      Helpers.send_success(
        conn,
        [
          @html_header,
          Text.format(params, false),
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

        conn
        |> Plug.Conn.put_resp_content_type("text/html")
        |> Plug.Conn.send_file(200, index_file)
    end
  end

  def get(conn, _headers) do
    send_plain_text(conn)
  end

  defp send_plain_text(conn) do
    params = build_params(conn)

    Helpers.send_success(
      conn,
      Text.format(
        params,
        if Map.get(conn.params, "plain", "false") == "true" do
          false
        else
          true
        end
      ),
      "text/plain"
    )
  end

  defp build_params(conn) do
    Params.new(conn)
    |> Params.data_type(conn)
    |> Params.offset(conn)
    |> Params.limit(conn)
    |> Params.order(conn)
    |> Params.order_direction(conn)
  end
end
