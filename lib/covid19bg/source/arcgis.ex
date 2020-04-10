defmodule Covid19bg.Source.Arcgis do
  alias Covid19bg.Source.LocationData

  @by_places_uri URI.parse(
                   "https://services2.arcgis.com" <>
                     "/ZIcxOCxrlGNlo0Hc/arcgis/rest/services/COVID19_stlm_table/FeatureServer/0/query" <>
                     "?f=json" <>
                     "&where=%D0%98%D0%BC%D0%B5_%D0%BD%D0%B0_%D0%BE%D0%B1%D0%BB%D0%B0%D1%81%D1%82%3C%3E%27%D0%9D%D0%B5%D0%BE%D0%BF%D1%80%D0%B5%D0%B4%D0%B5%D0%BB%D0%B5%D0%BD%D0%B0%20%D0%BB%D0%BE%D0%BA%D0%B0%D1%86%D0%B8%D1%8F%27" <>
                     "&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&resultOffset=0&cacheHint=true"
                 )
  def retrieve(type \\ :all)

  def retrieve(:all) do
    %{
      casesByLocation: retrieve(:by_places)
    }
  end

  def retrieve(:by_places) do
    {:ok, conn = %{socket: socket}} =
      Mint.HTTP1.connect(
        String.to_atom(@by_places_uri.scheme),
        @by_places_uri.host,
        @by_places_uri.port
      )

    try do
      {:ok, conn, request_ref} = Mint.HTTP.request(conn, "GET", path(@by_places_uri), [], "")

      receive do
        {_message_type, ^socket, _} = message ->
          {:ok, _conn, response} = Mint.HTTP.stream(conn, message)

          with {:ok, response} <- parse_response(response, request_ref),
               {:ok, data} <- transform_response(response) do
            data
          else
            error -> error
          end
      end
    after
      {:ok, _} = Mint.HTTP.close(conn)
    end
  end

  def location, do: "Bulgaria"

  def link, do: "https://www.arcgis.com"
  def description, do: "Данните са от НСИ"

  defp path(uri) do
    IO.iodata_to_binary([
      if(uri.path, do: uri.path, else: ["/"]),
      if(uri.query, do: ["?" | uri.query], else: []),
      if(uri.fragment, do: ["#" | uri.fragment], else: [])
    ])
  end

  defp parse_response(response, request_ref, response_data \\ %{})

  defp parse_response(
         [{:status, request_ref, status} | response],
         request_ref,
         response_data
       ) do
    parse_response(response, request_ref, Map.put(response_data, :status, status))
  end

  defp parse_response(
         [{:headers, request_ref, headers} | response],
         request_ref,
         response_data
       ) do
    parse_response(response, request_ref, Map.put(response_data, :headers, headers))
  end

  defp parse_response(
         [{:data, request_ref, data} | response],
         request_ref,
         response_data
       ) do
    parse_response(
      response,
      request_ref,
      Map.put(response_data, :response_body, Jason.decode!(data))
    )
  end

  defp parse_response(
         [{:done, request_ref} | response],
         request_ref,
         response_data
       ) do
    parse_response(response, request_ref, Map.put(response_data, :parsed, true))
  end

  defp parse_response([{_, mint_request_ref, _} | _], request_ref, _)
       when mint_request_ref != request_ref,
       do: {:error, :invalid_ref}

  defp parse_response([{_, mint_request_ref} | _], request_ref, _)
       when mint_request_ref != request_ref,
       do: {:error, :invalid_ref}

  defp parse_response([], _request_ref, response_data), do: {:ok, response_data}

  defp transform_response(%{status: 200, response_body: %{"features" => features}}) do
    response =
      features
      |> Enum.map(&transformer/1)
      |> LocationData.sort_and_rank()
    {:ok, response ++ [LocationData.add_summary(response, location())]}
  end

  defp transform_response(response) do
    {:error, "Bad server response", response}
  end

  defp transformer(%{
         "attributes" => %{
           "Активни" => active,
           "Излекувани" => recovered,
           "Име_на_област" => area,
           "Населено_място" => place,
           "Потвърдени" => total,
           "Умрели" => dead
         }
       }) do
    %LocationData{
      active: active,
      recovered: recovered,
      area: area,
      place: place,
      total: total,
      dead: dead
    }
  end
end
