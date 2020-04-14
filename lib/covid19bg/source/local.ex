defmodule Covid19bg.Source.Local do
  alias Covid19bg.Source.{Arcgis, Helpers, LocationData, SnifyCovidOpendataBulgaria}

  require Logger

  def retrieve(type \\ :all, place \\ "Bulgaria")

  def retrieve(:all, place) do
    %{
      casesByLocation: retrieve(:by_places),
      latest: retrieve(:latest),
      historical: retrieve(:historical, place)
    }
  end

  def retrieve(:by_places, place) do
    place = String.capitalize(place)

    retriever = fn store, store_module ->
      case store_module.get_latest(store, place) do
        {:ok, [nil], _} ->
          []

        {:ok, result, _} ->
          response = LocationData.sort_and_rank(result)

          summary =
            case retrieve(:latest, place) do
              %{summary: summary} ->
                %LocationData{
                  LocationData.add_summary(response, place)
                  | recovered_new: summary.recovered_new,
                    dead_new: summary.dead_new,
                    total_new: summary.total_new,
                    updated: summary.updated
                }

              {:error, _} ->
                LocationData.add_summary(response, place)
            end

          response ++ [summary]

        {:error, _} = error ->
          error
      end
    end

    with_store(retriever)
  end

  def retrieve(:latest, place) do
    retriever = fn store, store_module ->
      case store_module.get_latest_for_location(store, place) do
        {:ok, result, _} ->
          %{day: DateTime.to_date(result.updated), summary: result, locations: []}

        {:error, _} = error ->
          error
      end
    end

    with_store(retriever)
  end

  def retrieve(:historical, "sofia") do
    retrieve(:historical, "София")
  end

  def retrieve(:historical, place) do
    place = String.capitalize(place)
    place = Map.get(Helpers.cities_latin_cyrillic(), place, place)

    retriever = fn store, store_module ->
      case store_module.get_historical_for_location(store, place) do
        {:ok, result, _} ->
          result
          |> LocationData.sort_and_rank([:updated])
          |> Enum.reverse()

        {:error, _} = error ->
          error
      end
    end

    with_store(retriever)
  end

  def location, do: "Bulgaria"

  def link do
    "Cached from https://www.arcgis.com , https://www.worldometers.info/coronavirus/ , https://corona.lmao.ninja , https://corona.lmao.ninja, https://github.com/snify/covid-opendata-bulgaria"
  end

  def description do
    "Данните са от Coronavirus Tracker, Worldometers, НСИ "
  end

  def update_latest_from_sources(sources \\ [Arcgis, SnifyCovidOpendataBulgaria]) do
    sources
    |> Enum.map(fn source -> {source, source.retrieve(:by_places)} end)
    |> Enum.filter(fn {_, results} -> is_list(results) end)
    |> case do
      [_ | _] = results ->
        update_latest_from_results(results)

      [] ->
        []
    end
  end

  def universal_place_name(name), do: name

  defp update_latest_from_results([]) do
    Logger.warn("Latest update data was empty...")
    []
  end

  defp update_latest_from_results([{primary_source, primary} | rest]) do
    day =
      DateTime.utc_now()
      |> DateTime.shift_zone("Europe/Sofia")
      |> Kernel.elem(1)
      |> DateTime.to_date()

    locations =
      primary
      |> Enum.map(fn location ->
        rest
        |> Enum.map(fn {source, locations} ->
          Enum.find(locations, fn %LocationData{place: place} ->
            source.universal_place_name(place) ==
              primary_source.universal_place_name(location.place)
          end)
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.reduce(location, fn loc, acc ->
          Map.merge(acc, loc, fn key, val1, val2 ->
            if is_number(val1) && is_number(val2) && val2 > val1 && key not in [:total] do
              val2
            else
              val1
            end
          end)
        end)
      end)

    updater = fn store, store_module ->
      Enum.map(locations, fn location ->
        store_module.insert_historical(store, [%LocationData{location | updated: day}])
        store_module.update_latest(store, location)
      end)
    end

    with_store(updater)
  end

  defp with_store(action) when is_function(action, 2) do
    case Application.get_env(:covid19bg, :store) do
      {store_module, args} ->
        store_module
        |> Kernel.apply(:new, [args])
        |> action.(store_module)

      _ ->
        {:error, "Local storage is not configured"}
    end
  end
end
