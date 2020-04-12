defmodule Covid19bg.Source.Arcgis do
  alias Covid19bg.Source.{Helpers, LocationData}

  require Logger

  @by_places_uri URI.parse(
                   "https://services2.arcgis.com" <>
                     "/ZIcxOCxrlGNlo0Hc/arcgis/rest/services/COVID19_stlm_table/FeatureServer/0/query" <>
                     "?f=json" <>
                     "&where=%D0%98%D0%BC%D0%B5_%D0%BD%D0%B0_%D0%BE%D0%B1%D0%BB%D0%B0%D1%81%D1%82%3C%3E%27%D0%9D%D0%B5%D0%BE%D0%BF%D1%80%D0%B5%D0%B4%D0%B5%D0%BB%D0%B5%D0%BD%D0%B0%20%D0%BB%D0%BE%D0%BA%D0%B0%D1%86%D0%B8%D1%8F%27" <>
                     "&returnGeometry=false&spatialRel=esriSpatialRelIntersects&outFields=*&resultOffset=0&cacheHint=true"
                 )

  @historical URI.parse(
                "https://services2.arcgis.com/" <>
                  "ZIcxOCxrlGNlo0Hc/arcgis/rest/services/COVID19_date/FeatureServer/0/query" <>
                  "?f=json&where=1=1&outFields=*&orderByFields=%D0%94%D0%B0%D1%82%D0%B0%20asc" <>
                  "&resultOffset=0&resultRecordCount=2000"
              )

  def retrieve(type \\ :all, place \\ "Bulgaria")

  def retrieve(:all, place) do
    %{
      casesByLocation: retrieve(:by_places),
      latest: retrieve(:latest),
      historical: retrieve(:historical, place)
    }
  end

  def retrieve(:by_places, _) do
    Helpers.http_request(@by_places_uri, &transform_response/1)
  end

  def retrieve(:latest, _) do
    Helpers.http_request(@historical, &transform_latest_response/1)
  end

  def retrieve(:historical, place) do
    Helpers.http_request(@historical, &transform_historical_response_for_place(&1, place))
  end

  def location, do: "Bulgaria"

  def link, do: "https://www.arcgis.com"
  def description, do: "Данните са от НСИ"

  def universal_place_name(name), do: name

  defp transform_response(%{status_code: 200, body: body}) do
    %{"features" => features} = Jason.decode!(body)

    response =
      features
      |> Enum.map(&transformer/1)
      |> LocationData.sort_and_rank()

    summary =
      case retrieve(:latest) do
        %{summary: summary} ->
          %LocationData{summary | summary: true, rank: ""}

        {:error, _} = error ->
          Logger.warn(
            "Problem while fetching historical data from (#{description()}) : #{inspect(error)}"
          )

          LocationData.add_summary(response, location())
      end

    {:ok, response ++ [summary]}
  end

  defp transform_response(response) do
    {:error, "Bad server response", response}
  end

  defp transformer(%{
         "attributes" => %{
           "Активни" => active,
           "Излекувани" => recovered,
           "Населено_място" => place,
           "Потвърдени" => total,
           "Умрели" => dead
         }
       }) do
    %LocationData{
      active: active,
      recovered: recovered,
      area: location(),
      place: place,
      total: total,
      dead: dead
    }
  end

  defp transform_latest_response(response) do
    response
    |> reduce_historical_response()
    |> (fn
          {:ok, %{updated: updated, locations: locations}} ->
            bulgaria = List.last(locations)

            {:ok,
             %{
               day: DateTime.to_date(updated),
               summary: %{bulgaria | updated: updated},
               locations: []
             }}

          {:error, _} = error ->
            error
        end).()
  end

  defp extract_locations(features) do
    locations =
      features
      |> Enum.reduce(%{}, fn
        %{"attributes" => %{"Брой" => value, "Вид_регистрирани" => type, "Дата" => date}}, acc ->
          key =
            case type do
              "Потвърдени" -> :total
              "Умрели" -> :dead
              "Излекувани" -> :recovered
            end

          Map.update(acc, date, %{key => value}, &Map.put(&1, key, value))
      end)
      |> Enum.map(fn {date, %{total: total, dead: dead, recovered: recovered}} ->
        %LocationData{
          area: "World",
          place: location(),
          place_code: "bg",
          total_new: total,
          dead_new: dead,
          recovered_new: recovered,
          updated: date
        }
      end)
      |> LocationData.sort_and_rank([:updated])
      |> Enum.map(fn %LocationData{updated: updated} = location ->
        %LocationData{location | updated: DateTime.from_unix!(updated, :millisecond)}
      end)

    %{
      locations: locations,
      updated: List.first(locations).updated
    }
  end

  defp reduce_historical_response(%{status_code: 200, body: body}) do
    case Jason.decode(body) do
      {:ok, data} ->
        {:ok, extract_historical_data(data, location())}

      {:error, _} = error ->
        error
    end
  end

  defp reduce_historical_response(response) do
    {:error, "Bad server response", response}
  end

  defp transform_historical_response_for_place(%{status_code: 200, body: body}, place) do
    case Jason.decode(body) do
      {:ok, data} ->
        {:ok, extract_historical_data(data, place).locations}

      {:error, _} = error ->
        error
    end
  end

  defp transform_historical_response_for_place(response, _) do
    {:error, "Bad server response", response}
  end

  defp extract_historical_data(%{"features" => features}, "Bulgaria") do
    data = %{locations: locations} = extract_locations(features)

    result =
      locations
      |> Enum.map(fn %LocationData{updated: updated} = location ->
        %LocationData{location | updated: updated |> DateTime.to_date() |> Date.to_iso8601()}
      end)
      |> LocationData.sort_and_rank([:updated])
      |> Enum.reverse()
      |> Enum.reduce([], fn location, acc ->
        prev = List.first(acc) || %LocationData{}
        total = prev.total + location.total_new
        dead = prev.dead + location.dead_new
        recovered = prev.recovered + location.recovered_new
        active = total - (dead + recovered)

        [
          %LocationData{location | total: total, dead: dead, recovered: recovered, active: active}
          | acc
        ]
      end)
      |> Enum.reverse()

    %{data | locations: result}
  end
end
