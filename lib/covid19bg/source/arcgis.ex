defmodule Covid19bg.Source.Arcgis do
  alias Covid19bg.Source.{Helpers, LocationData}

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

  def retrieve(type \\ :all)

  def retrieve(:all) do
    %{
      casesByLocation: retrieve(:by_places)
    }
  end

  def retrieve(:by_places) do
    Helpers.http_request(@by_places_uri, &transform_response/1)
  end

  def retrieve(:latest) do
    Helpers.http_request(@historical, &transform_latest_response/1)
  end

  def location, do: "Bulgaria"

  def link, do: "https://www.arcgis.com"
  def description, do: "Данните са от НСИ"

  defp transform_response(%{status_code: 200, body: body}) do
    %{"features" => features} = Jason.decode!(body)

    response =
      features
      |> Enum.map(&transformer/1)
      |> LocationData.sort_and_rank()

    summary =
      case retrieve(:latest) do
        %{summary: summary} ->
          %LocationData{
            LocationData.add_summary(response, location())
            | recovered_new: summary.recovered_new,
              dead_new: summary.dead_new,
              total_new: summary.total_new,
              updated: summary.updated
          }

        {:error, _} ->
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
    |> transform_historical_response()
    |> (fn
          {:ok, result} ->
            %{
              updated: updated
            } = bulgaria = List.first(result)

            {:ok, %{day: DateTime.to_date(updated), summary: bulgaria, locations: []}}

          {:error, _} = error ->
            error
        end).()
  end

  defp transform_historical_response(%{status_code: 200, body: body}) do
    case Jason.decode(body) do
      {:ok, %{"features" => features}} ->
        result =
          features
          |> Enum.reduce(%{}, fn
            %{"attributes" => %{"Брой" => value, "Вид_регистрирани" => type, "Дата" => date}},
            acc ->
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

        {:ok, result}

      {:error, _} = error ->
        error
    end
  end

  defp transform_historical_response(response) do
    {:error, "Bad server response", response}
  end
end
