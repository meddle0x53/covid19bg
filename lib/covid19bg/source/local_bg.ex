defmodule Covid19bg.Source.LocalBg do
  alias Covid19bg.Source.{Arcgis, LocationData, SnifyCovidOpendataBulgaria}

  def retrieve(type \\ :all)

  def retrieve(:all) do
    %{
      casesByLocation: retrieve(:by_places)
    }
  end

  def retrieve(:by_places) do
    case Application.get_env(:covid19bg, :store) do
      {store_module, args} ->
        store = Kernel.apply(store_module, :new, args)

        case store_module.get_latest(store, location()) do
          {:ok, result, _} ->
            response = LocationData.sort_and_rank(result)

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

            response ++ [summary]

          {:error, _} = error ->
            error
        end

      _ ->
        {:error, "Local storage is not configured"}
    end
  end

  def retrieve(:latest) do
    case Application.get_env(:covid19bg, :store) do
      {store_module, args} ->
        store = Kernel.apply(store_module, :new, args)

        case store_module.get_latest_for_location(store, location()) do
          {:ok, result, _} ->
            %{day: DateTime.to_date(result.updated), summary: result, locations: []}

          {:error, _} = error ->
            error
        end

      _ ->
        {:error, "Local storage is not configured"}
    end
  end

  def location, do: "Bulgaria"

  def link, do: "Cached from https://www.arcgis.com"
  def description, do: "Данните са от НСИ"

  def update_latest_from_sources(sources \\ [Arcgis, SnifyCovidOpendataBulgaria]) do
    sources
    |> Enum.map(fn source -> {source, source.retrieve(:by_places)} end)
    |> Enum.filter(fn {_, results} -> is_list(results) end)
    |> case do
      results when is_list(results) ->
        update_latest_from_results(results)

      [] ->
        :noop
    end
  end

  def universal_place_name(name), do: name

  defp update_latest_from_results([]), do: :noop

  defp update_latest_from_results([{primary_source, primary} | rest]) do
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
        store_module.update_latest(store, location)
      end)
    end

    with_store(updater)
  end

  defp with_store(action) when is_function(action, 2) do
    case Application.get_env(:covid19bg, :store) do
      {store_module, args} ->
        store_module
        |> Kernel.apply(:new, args)
        |> action.(store_module)

      _ ->
        {:error, "Local storage is not configured"}
    end
  end
end
