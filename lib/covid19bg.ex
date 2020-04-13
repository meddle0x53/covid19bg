defmodule Covid19bg do
  alias Covid19bg.Source.LocationData

  def initialize(_args) do
    case Application.get_env(:covid19bg, :store) do
      {store_module, init_args} when is_atom(store_module) and is_list(init_args) ->
        store = %{__struct__: ^store_module} = Kernel.apply(store_module, :new, [init_args])
        {:ok, _store} = store_module.init(store)
        updater = store_module.updater()

        init_args
        |> Keyword.get(:updaters, [[]])
        |> Enum.map(fn updater_args ->
          Supervisor.start_child(Covid19bg.Supervisor, updater.child_spec(updater_args))
        end)

        :ok

      _ ->
        :ok
    end
  end

  def initialize_countries do
    case Application.get_env(:covid19bg, :store) do
      {store_module, init_args} when is_atom(store_module) and is_list(init_args) ->
        store = %{__struct__: ^store_module} = Kernel.apply(store_module, :new, init_args)

        locations =
          Countriex.all()
          |> Enum.map(fn %{name: place, un_locode: un_locode} ->
            place_code = if(String.valid?(un_locode), do: String.downcase(un_locode), else: "???")
            %LocationData{place: place, place_code: place_code, area: "World"}
          end)

        locations = [%LocationData{place: "World", area: "World"} | locations]
        {:ok, _store} = store_module.initialize_locations(store, locations)

        :ok

      _ ->
        :ok
    end
  end
end
