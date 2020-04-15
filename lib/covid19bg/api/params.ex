defmodule Covid19bg.API.Params do
  alias Covid19bg.Source.LocationData

  @enforce_keys [:source, :location]
  defstruct [
    :source,
    :location,
    offset: 0,
    limit: 1000,
    order_keys: [],
    data_type: :by_places,
    order_direction: :desc
  ]

  @order_keys Map.keys(%LocationData{})

  def new(conn) do
    source = get_source(conn)
    location = Map.get(conn.params, "location", source.location())

    %__MODULE__{source: source, location: location}
  end

  def data_type(%__MODULE__{} = params, conn) do
    data_type =
      case Map.get(conn.params, "data", "by_places") do
        "historical" -> :historical
        "by_places" -> :by_places
        "latest" -> :latest
        "all" -> :all
        _ -> :by_places
      end

    %__MODULE__{params | data_type: data_type}
  end

  def offset(%__MODULE__{} = params, conn) do
    %__MODULE__{
      params
      | offset: Map.get(conn.params, "offset", "0") |> String.to_integer()
    }
  end

  def limit(%__MODULE__{} = params, conn) do
    %__MODULE__{
      params
      | limit: Map.get(conn.params, "limit", "1000") |> String.to_integer()
    }
  end

  def order(%__MODULE__{} = params, conn) do
    order_keys =
      conn.params
      |> Map.get("order", "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.to_existing_atom/1)
      |> Enum.filter(&(&1 in @order_keys))

    %__MODULE__{params | order_keys: order_keys}
  end

  def order_direction(%__MODULE__{} = params, conn) do
    order_direction =
      conn.params
      |> Map.get("order_direction", "desc")
      |> String.to_existing_atom()

    %__MODULE__{params | order_direction: order_direction}
  end

  defp get_source(conn) do
    case Map.get(conn.params, "source", "local") do
      "arcgis" -> Covid19bg.Source.Arcgis
      "nsi" -> Covid19bg.Source.Arcgis
      "local" -> Covid19bg.Source.Local
      "snify" -> Covid19bg.Source.SnifyCovidOpendataBulgaria
      "world" -> Covid19bg.Source.World
      _ -> Covid19bg.Source.Local
    end
  end
end
