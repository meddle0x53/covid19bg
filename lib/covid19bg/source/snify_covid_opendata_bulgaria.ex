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
    "Burgas" => "Бургас",
    "Blagoevgrad" => "Благоевград",
    "Varna" => "Варна",
    "Stara Zagora" => "Стара Загора",
    "Pazardzhik" => "Пазарджик",
    "Kardzhali" => "Кърджали",
    "Dobrich" => "Добрич",
    "Sliven" => "Сливен",
    "Pleven" => "Плевен",
    "Haskovo" => "Хасково",
    "Pernik" => "Перник",
    "Shumen" => "Шумен",
    "Montana" => "Монтана",
    "Vratsa" => "Враца",
    "Vidin" => "Видин",
    "Silistra" => "Силистра",
    "Lovech" => "Ловеч",
    "Gabrovo" => "Габрово"
  }
  # @cities_reverse @cities |> Enum.map(fn {k, v} -> {v, k} end) |> Enum.into(%{})

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
    Map.get(@cities, name, name)
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
            |> Enum.map(fn {place, total} ->
              %LocationData{
                area: location(),
                place: universal_place_name(place),
                total: total,
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
end
