defmodule Covid19bg.Source.SnifyCovidOpendataBulgaria do
  alias Covid19bg.Source.{Helpers, LocationData}

  @historical URI.parse(
                "https://raw.githubusercontent.com" <>
                  "/snify/covid-opendata-bulgaria/master/data/historical_data.json"
              )

  @latest URI.parse(
            "https://raw.githubusercontent.com" <>
              "/snify/covid-opendata-bulgaria/master/data/latest_data.json"
          )

  @cities %{
    "Veliko Tarnovo" => "Велико Търново",
    "Kyustendil" => "Кюстендил",
    "Ruse" => "Русе",
    "Smolyan" => "Смолян",
    "Sofia City" => "София",
    "Plovdiv" => "Пловдив",
    "Burgas" => "Бургас"
  }

  def retrieve(type \\ :all)

  def retrieve(:all) do
    %{
      casesByLocation: retrieve(:by_places),
      latest: retrieve(:latest)
    }
  end

  def retrieve(:by_places) do
    Helpers.http_request(@historical, &transform_historical_response/1)
  end

  def retrieve(:latest) do
    Helpers.http_request(@latest, &transform_latest_response/1)
  end

  def location, do: "Bulgaria"

  def link, do: "https://github.com/snify/covid-opendata-bulgaria"
  def description, do: "Данните са от Wikipedia coronavirus pandemic medical cases"

  defp transform_historical_response(%{status_code: 200, body: body}) do
    case Jason.decode(body) do
      {:ok, data} ->
        %{
          "confirmed_cases_total" => total,
          "deaths_total" => dead,
          "recoveries_total" => recovered,
          "active_cases_total" => active
        } = List.first(data)

        summary = %LocationData{
          active: active,
          recovered: recovered,
          area: location(),
          place: "World",
          total: total,
          dead: dead,
          summary: true
        }

        response =
          data
          |> Enum.reduce(%{}, fn update, acc ->
            update
            |> Map.get("data", [])
            |> Enum.reduce(acc, fn %{"name" => name, "total_cases" => total}, current ->
              Map.update(current, name, total, &(&1 + total))
            end)
          end)
          |> Enum.map(fn {place, total} ->
            %LocationData{
              area: location(),
              place: convert_city_name(place),
              total: total
            }
          end)
          |> LocationData.sort_and_rank()

        {:ok, response ++ [summary]}

      {:error, _} = error ->
        error
    end
  end

  defp transform_historical_response(response) do
    {:error, "Bad server response", response}
  end

  defp transform_latest_response(%{status_code: 200, body: body}) do
    case Jason.decode(body) do
      {:ok, data} ->
        %{
          "active_cases_hospitalized" => in_hospital,
          "active_cases_icu" => critical,
          "active_cases_total" => active,
          "confirmed_cases_new" => total_new,
          "confirmed_cases_total" => total,
          "data" => locations,
          "date" => date,
          "deaths_new" => dead_new,
          "deaths_total" => dead,
          "recoveries_new" => recovered_new,
          "recoveries_total" => recovered
        } = data

        bulgaria = %LocationData{
          active: active,
          in_hospital: in_hospital,
          critical: critical,
          recovered: recovered,
          recovered_new: recovered_new,
          area: "World",
          place: location(),
          place_code: "bg",
          total: total,
          total_new: total_new,
          dead: dead,
          dead_new: dead_new,
          summary: true
        }

        {:ok, day} =
          Kernel.apply(
            Date,
            :new,
            date |> String.split("-") |> Enum.reverse() |> Enum.map(&String.to_integer/1)
          )

        locations =
          locations
          |> Enum.map(fn %{"name" => place, "total_cases" => total} ->
            %LocationData{
              area: location(),
              place: convert_city_name(place),
              total: total
            }
          end)
          |> LocationData.sort_and_rank()

        {:ok, %{day: day, summary: bulgaria, locations: locations}}

      {:error, _} = error ->
        error
    end
  end

  defp transform_latest_response(response) do
    {:error, "Bad server response", response}
  end

  defp convert_city_name(name) do
    Map.get(@cities, name, name)
  end
end
