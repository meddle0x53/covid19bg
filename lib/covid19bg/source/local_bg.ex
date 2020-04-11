defmodule Covid19bg.Source.LocalBg do
  alias Covid19bg.Source.LocationData

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
end
