defmodule Covid19bg.Source.World do
  alias Covid19bg.Source.{Helpers, LocationData}

  @by_places_uri URI.parse("https://corona.lmao.ninja/v2/countries?sort=cases")

  @historical URI.parse("https://coronavirus-tracker-api.herokuapp.com/all")

  def retrieve(type \\ :all, place \\ "World")

  def retrieve(:all, place) do
    %{
      casesByLocation: retrieve(:by_places),
      latest: retrieve(:latest),
      historical: retrieve(:historical, place)
    }
  end

  def retrieve(:by_places, _) do
    Helpers.http_request(@by_places_uri, &transform_by_places_response/1)
  end

  def retrieve(:latest, args) do
    :by_places
    |> retrieve(args)
    |> case do
      list when is_list(list) ->
        summary = List.last(list)

        %{
          day: DateTime.to_date(summary.updated),
          summary: summary,
          locations: []
        }

      {:error, _} = error ->
        error
    end
  end

  def retrieve(:historical, place) do
    Helpers.http_request(@historical, &transform_historical_response_for_place(&1, place))
  end

  def location, do: "World"

  def link,
    do:
      "https://www.worldometers.info/coronavirus/ , https://corona.lmao.ninja , https://corona.lmao.ninja"

  def description, do: "Uses Worldometers and Corona"

  defp transform_by_places_response(%{status_code: 200, body: body}) do
    locations =
      Jason.decode!(body)
      |> Enum.map(&transformer/1)
      |> LocationData.sort_and_rank()

    summary = LocationData.add_summary(locations, location())

    {:ok, locations ++ [summary]}
  end

  defp transform_by_places_response(response) do
    {:error, "Bad server response", response}
  end

  defp transformer(%{
         "active" => active,
         "cases" => total,
         "country" => place,
         "critical" => critical,
         "deaths" => dead,
         "recovered" => recovered,
         "todayCases" => total_new,
         "todayDeaths" => dead_new,
         "updated" => updated
       }) do
    %LocationData{
      active: active,
      recovered: recovered,
      area: location(),
      place: place,
      total: total,
      total_new: total_new,
      dead: dead,
      dead_new: dead_new,
      critical: critical,
      updated: DateTime.from_unix!(updated, :millisecond)
    }
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

  defp extract_historical_data(data, place) when place in ~w(world World) do
    data
    |> Enum.map(fn {type, values} ->
      historical =
        values
        |> Map.get("locations", [])
        |> Enum.reduce(%{}, fn %{"history" => history}, acc ->
          history
          |> Enum.map(fn {date, value} ->
            [m, d, y] =
              date
              |> String.split("/")
              |> List.update_at(2, fn v -> "20#{v}" end)
              |> Enum.map(&String.to_integer/1)

            {Date.new(y, m, d) |> elem(1) |> Date.to_iso8601(), value}
          end)
          |> Enum.into(%{})
          |> Map.merge(acc, fn _k, v1, v2 ->
            v1 + v2
          end)
        end)

      {type, historical}
    end)
    |> Enum.into(%{})
    |> extract_historical_data_locations(place)
  end

  defp extract_historical_data(data, place) do
    filter = String.capitalize(place)

    data
    |> Enum.map(fn {type, values} ->
      historical =
        values
        |> Map.get("locations", [])
        |> Enum.find(fn %{"country" => country} ->
          country == filter
        end)
        |> case do
          nil ->
            %{}

          %{"history" => history} ->
            history
            |> Enum.map(fn {date, value} ->
              [m, d, y] =
                date
                |> String.split("/")
                |> List.update_at(2, fn v -> "20#{v}" end)
                |> Enum.map(&String.to_integer/1)

              {Date.new(y, m, d) |> elem(1) |> Date.to_iso8601(), value}
            end)
            |> Enum.into(%{})
        end

      {type, historical}
    end)
    |> Enum.into(%{})
    |> extract_historical_data_locations(filter)
  end

  def extract_historical_data_locations(history_map, filter) do
    history_map
    |> Map.get("confirmed", %{})
    |> Enum.reduce([], fn {date, value}, acc ->
      location_data = %LocationData{
        total: value,
        dead: history_map |> Map.get("deaths", %{}) |> Map.get(date, 0),
        recovered: history_map |> Map.get("recovered", %{}) |> Map.get(date, 0),
        updated: date,
        place: filter,
        place_code: (Countriex.get_by(:name, filter) || %{}) |> Map.get(:un_locode, "???"),
        area: location()
      }

      [location_data | acc]
    end)
    |> LocationData.sort_and_rank([:updated])
    |> Enum.reverse()
    |> Enum.reduce([], fn location, acc ->
      prev = List.first(acc) || %LocationData{}
      total_new = location.total - prev.total
      dead_new = location.dead - prev.dead
      recovered_new = location.recovered - prev.recovered
      active = location.total - (location.dead + location.recovered)

      [
        %LocationData{
          location
          | total_new: total_new,
            dead_new: dead_new,
            recovered_new: recovered_new,
            active: active
        }
        | acc
      ]
    end)
    |> Enum.reverse()
  end
end
