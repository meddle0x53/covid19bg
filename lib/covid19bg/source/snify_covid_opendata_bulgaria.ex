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

  @unknown_when %{
    "Blagoevgrad" => 1,
    "Burgas" => 1,
    "Varna" => 8,
    "Veliko Tarnovo" => 0,
    "Vidin" => 0,
    "Vratsa" => 0,
    "Dobrich" => 0,
    "Gabrovo" => 2,
    "Kardzhali" => 0,
    "Kyustendil" => 0,
    "Lovech" => 0,
    "Montana" => 15,
    "Pazardzhik" => 0,
    "Pernik" => 3,
    "Pleven" => 1,
    "Plovdiv" => 3,
    "Ruse" => 0,
    "Silistra" => 0,
    "Sliven" => 0,
    "Smolyan" => 0,
    "Sofia" => 61,
    "Sofia City" => 61,
    "Stara Zagora" => 0,
    "Shumen" => 0,
    "Haskovo" => 0
  }

  def retrieve(type \\ :all, place \\ "Bulgaria")

  def retrieve(:all, place) do
    %{
      casesByLocation: retrieve(:by_places),
      latest: retrieve(:latest),
      historical: retrieve(:historical, place)
    }
  end

  def retrieve(:by_places, _) do
    Helpers.http_request(@historical, &transform_historical_response_by_places/1)
  end

  def retrieve(:latest, _) do
    Helpers.http_request(@latest, &transform_latest_response/1)
  end

  def retrieve(:historical, place) do
    Helpers.http_request(@historical, &transform_historical_response_for_place(&1, place))
  end

  def location, do: "Bulgaria"

  def link, do: "https://github.com/snify/covid-opendata-bulgaria"
  def description, do: "Данните са от Wikipedia coronavirus pandemic medical cases"

  def universal_place_name(name) do
    Map.get(Helpers.cities_latin_cyrillic(), name, name)
  end

  defp transform_historical_response_by_places(%{status_code: 200, body: body}) do
    case Jason.decode(body) do
      {:ok, data} ->
        today =
          Date.utc_today()
          |> Date.to_string()
          |> String.split("-")
          |> Enum.reverse()
          |> Enum.join("-")

        %{
          "date" => date,
          "confirmed_cases_total" => total,
          "deaths_total" => dead,
          "recoveries_total" => recovered,
          "active_cases_total" => active,
          "confirmed_cases_new" => total_new,
          "deaths_new" => dead_new,
          "recoveries_new" => recovered_new,
          "active_cases_icu" => critical,
          "active_cases_hospitalized" => in_hospital,
          "data" => latest_locations
        } = List.first(data)

        if today == date do
          summary = %LocationData{
            active: active,
            recovered: recovered,
            recovered_new: recovered_new,
            area: "World",
            place: location(),
            total: total,
            total_new: total_new,
            dead: dead,
            dead_new: dead_new,
            summary: true,
            critical: critical,
            in_hospital: in_hospital,
            rank: ""
          }

          locations_new =
            latest_locations
            |> Enum.reduce(%{}, fn %{"name" => name, "total_cases" => total}, current ->
              Map.put(current, name, total)
            end)

          response =
            data
            |> Enum.reduce(%{}, fn update, acc ->
              update
              |> Map.get("data", [])
              |> Enum.reduce(acc, fn %{"name" => name, "total_cases" => total}, current ->
                Map.update(current, name, total, &(&1 + total))
              end)
            end)
            |> Enum.reject(fn {place, _} -> place == "Unknown" end)
            |> Enum.map(fn {place, total} ->
              %LocationData{
                area: location(),
                place: universal_place_name(place),
                total: total + Map.get(@unknown_when, place, 0),
                total_new: locations_new[place]
              }
            end)
            |> LocationData.sort_and_rank()

          {:ok, response ++ [summary]}
        else
          {:error, :no_recent_data}
        end

      {:error, _} = error ->
        error
    end
  end

  defp transform_historical_response_by_places(response) do
    {:error, "Bad server response", response}
  end

  defp transform_historical_response_for_place(%{status_code: 200, body: body}, place) do
    case Jason.decode(body) do
      {:ok, data} ->
        {:ok, extract_historical_data(data, place)}

      {:error, _} = error ->
        error
    end
  end

  defp transform_historical_response_for_place(response, _) do
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
              place: universal_place_name(place),
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

  def extract_historical_data(historical_data, "Bulgaria") do
    historical_data
    |> Enum.map(fn data ->
      %{
        "active_cases_hospitalized" => in_hospital,
        "active_cases_icu" => critical,
        "active_cases_total" => active,
        "confirmed_cases_new" => total_new,
        "confirmed_cases_total" => total,
        "date" => date,
        "deaths_new" => dead_new,
        "deaths_total" => dead,
        "recoveries_new" => recovered_new,
        "recoveries_total" => recovered
      } = data

      day = date |> String.split("-") |> Enum.reverse() |> Enum.join("-")

      %LocationData{
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
        updated: day,
        summary: true
      }
    end)
    |> LocationData.sort_and_rank([:updated])
    |> Enum.reverse()
  end

  def extract_historical_data(historical_data, city) do
    filter = String.capitalize(city)
    filter = Map.get(Helpers.cities_cyrillic_latin(), filter, filter)

    historical_data
    |> Enum.map(fn data ->
      %{"date" => date, "data" => city_data} = data

      city_data
      |> Enum.find(fn %{"name" => name} -> name == filter || name == "#{filter} City" end)
      |> case do
        %{"name" => name, "total_cases" => total_new} ->
          day = date |> String.split("-") |> Enum.reverse() |> Enum.join("-")

          %LocationData{
            area: location(),
            place: universal_place_name(name),
            total_new: total_new,
            updated: day
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> LocationData.sort_and_rank([:updated])
    |> Kernel.++(
      case Map.get(@unknown_when, filter, 0) do
        n when n > 0 ->
          [
            %LocationData{
              area: location(),
              place: filter,
              total_new: n,
              updated: "UNKNOWN"
            }
          ]

        _ ->
          []
      end
    )
    |> Enum.reverse()
    |> Enum.reduce([], fn location, acc ->
      prev = List.first(acc) || %LocationData{}
      total = prev.total + location.total_new

      [%LocationData{location | total: total} | acc]
    end)
    |> Enum.reverse()
  end
end
