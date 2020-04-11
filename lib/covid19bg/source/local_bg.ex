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

            response ++ [LocationData.add_summary(response, location())]

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
