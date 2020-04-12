defmodule Covid19bg.Store.Postgres do
  alias Covid19bg.Source.LocationData
  @default_pool_size 3
  @transaction_timeout 20_000

  @schema_file_path Path.join([File.cwd!(), "config", "schema.sql"])
  @external_resource Path.join([File.cwd!(), "config", "schema.sql"])
  @schema File.read!(@schema_file_path)

  defstruct connection: nil, schema: "public"

  def new() do
    case Application.get_env(:covid19bg, :store) do
      {__MODULE__, settings} ->
        new(settings)

      _ ->
        {:error, :store_not_configured}
    end
  end

  def new(settings) do
    pool_settings = [
      pool_size: @default_pool_size,
      name: :postgres_connections
    ]

    args =
      pool_settings
      |> Keyword.merge(settings)
      |> Keyword.delete(:updaters)

    spec = %{
      id: :postgres_connections,
      start: {Postgrex, :start_link, [args]},
      restart: :transient
    }

    case Supervisor.start_child(Covid19bg.Supervisor, spec) do
      {:ok, pid} -> %__MODULE__{connection: pid}
      {:error, {:already_started, pid}} -> %__MODULE__{connection: pid}
    end
  end

  def updater, do: Covid19bg.Store.Postgres.Updater

  def init(%__MODULE__{connection: conn} = store) do
    @schema
    |> String.split(";\n\n", trim: true)
    |> Enum.map(fn query -> Postgrex.query(conn, query, []) end)
    |> Enum.filter(fn
      {:ok, _} ->
        false

      {:error, _} ->
        true
    end)
    |> case do
      [] -> {:ok, store}
      errors -> {:error, errors}
    end
  end

  def initialize_locations(%__MODULE__{} = store, []), do: {:ok, store}

  def initialize_locations(
        %__MODULE__{connection: conn, schema: schema} = store,
        [%LocationData{} | _] = locations
      ) do
    f = fn connection ->
      locations
      |> Enum.map(fn %LocationData{place: place, place_code: code, area: area} ->
        Postgrex.query(connection, "SELECT #{schema}_create_location($1, $2, $3)", [
          place,
          code,
          area
        ])
      end)
      |> List.last()
    end

    case Postgrex.transaction(conn, f, timeout: @transaction_timeout) do
      {:ok, _} -> {:ok, store}
      {:error, _} = error -> error
    end
  end

  def update_latest(
        %__MODULE__{connection: conn, schema: schema} = store,
        %LocationData{} = location
      ) do
    query =
      "SELECT #{schema}_update_latest_stats($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)"

    args = [
      location.place,
      location.place_code,
      location.area,
      location.total,
      location.total_new,
      location.dead,
      location.dead_new,
      location.recovered,
      location.recovered_new,
      location.active,
      location.in_hospital,
      location.critical,
      DateTime.utc_now()
    ]

    case Postgrex.query(conn, query, args) do
      {:ok, _} -> {:ok, store}
      {:error, _} = error -> error
    end
  end

  def get_latest(
        %__MODULE__{schema: schema} = store,
        parent_location
      ) do
    query =
      "SELECT * FROM #{schema}.latest_stats WHERE location IN (SELECT name FROM #{schema}.locations WHERE parent_location = $1)"

    args = [parent_location]
    get_location_data(store, parent_location, query, args)
  end

  def get_latest_for_location(%__MODULE__{schema: schema} = store, location) do
    query = "SELECT * FROM #{schema}.latest_stats WHERE location = $1"

    args = [location]

    store
    |> get_location_data(location, query, args)
    |> case do
      {:ok, [result], store} ->
        {:ok, result, store}

      {:error, _} = error ->
        error
    end
  end

  def get_historical_for_location(%__MODULE__{schema: schema} = store, location) do
    query = "SELECT * FROM #{schema}.historical_stats WHERE location = $1"

    args = [location]

    store
    |> get_location_data(location, query, args)
    |> case do
      {:ok, result, store} ->
        {:ok, result, store}

      {:error, _} = error ->
        error
    end
  end

  defp get_location_data(%__MODULE__{connection: conn} = store, parent_location, query, args) do
    case Postgrex.query(conn, query, args) do
      {:ok, %Postgrex.Result{rows: rows}} ->
        stats =
          rows
          |> Enum.map(fn [
                           location,
                           total,
                           total_new,
                           dead,
                           dead_new,
                           recovered,
                           recovered_new,
                           active,
                           in_hospital,
                           critical,
                           updated
                         ] ->
            updated_val =
              case updated do
                %Date{} = date -> Date.to_iso8601(date)
                timestamp -> DateTime.from_naive!(timestamp, "Etc/UTC")
              end

            %LocationData{
              area: parent_location,
              place: location,
              total: total,
              total_new: total_new,
              dead: dead,
              dead_new: dead_new,
              recovered: recovered,
              recovered_new: recovered_new,
              active: active,
              in_hospital: in_hospital,
              critical: critical,
              updated: updated_val
            }
          end)

        {:ok, stats, store}

      {:error, _} = error ->
        error
    end
  end

  def insert_historical(store, []), do: {:ok, store}

  def insert_historical(
        %__MODULE__{connection: conn, schema: schema} = store,
        [%LocationData{} | _] = locations
      ) do
    query =
      "SELECT #{schema}_insert_historical_stats($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)"

    f = fn connection ->
      locations
      |> Enum.map(fn location ->
        args = [
          location.place,
          location.place_code,
          location.area,
          location.total,
          location.total_new,
          location.dead,
          location.dead_new,
          location.recovered,
          location.recovered_new,
          location.active,
          location.in_hospital,
          location.critical,
          if(String.valid?(location.updated),
            do: Date.from_iso8601!(location.updated),
            else: location.updated
          )
        ]

        Postgrex.query(connection, query, args)
      end)
      |> List.last()
    end

    case Postgrex.transaction(conn, f, timeout: @transaction_timeout) do
      {:ok, _} -> {:ok, store}
      {:error, _} = error -> error
    end
  end
end
