defmodule Covid19bg.Store.Postgres.Updater do
  use GenServer

  alias Covid19bg.Source.{Arcgis, Local, SnifyCovidOpendataBulgaria}

  require Logger

  @default_sources [Arcgis, SnifyCovidOpendataBulgaria]
  @default_update_interval 10 * 60 * 1000
  @default_name __MODULE__

  def child_spec(args) do
    %{
      id: Keyword.get(args, :name, @default_name),
      start: {__MODULE__, :start_link, [args]}
    }
  end

  @spec start_link(module) :: GenServer.on_start()
  def start_link(settings) do
    GenServer.start_link(__MODULE__, settings, name: Keyword.get(settings, :name, @default_name))
  end

  def init(settings) when is_list(settings) do
    state = init_state(settings)

    send(self(), :initialize)

    {:ok, state}
  end

  defp init_state(settings) do
    %{
      sources: Keyword.get(settings, :sources, @default_sources),
      update_interval: Keyword.get(settings, :update_interval, @default_update_interval),
      destination: Keyword.get(settings, :destination, Local),
      check_for_updates: Keyword.get(settings, :check_for_updates, true)
    }
  end

  def handle_info(:initialize, state) do
    try_check_after_interval(state.check_for_updates, state.update_interval)

    {:noreply, state}
  end

  def handle_info(:check_updates, %{ref: ref} = state) when is_reference(ref) do
    Logger.warn("Trying to initiate update while there is a running update!")

    {:noreply, state}
  end

  def handle_info(:check_updates, state) do
    %Task{ref: ref} =
      Task.Supervisor.async_nolink(
        :tasks_supervisor,
        state.destination,
        :update_latest_from_sources,
        [state.sources]
      )

    {:noreply, Map.put(state, :ref, ref)}
  end

  def handle_info({ref, results}, %{ref: ref, destination: destination, sources: sources} = state)
      when is_reference(ref) do
    results
    |> Enum.reject(fn {status, _} -> status == :ok end)
    |> case do
      [] ->
        Logger.info("Successfully updated (#{destination}) from sources (#{inspect(sources)})")

      errors ->
        Logger.warn(
          "There were some problems while updating (#{destination}) from sources (#{
            inspect(sources)
          })"
        )

        Logger.warn("Errors: #{inspect(errors)}")
    end

    {:noreply, state}
  end

  def handle_info({ref, results}, state) when is_reference(ref) do
    Logger.warn("Bad update reference with update results #{inspect(results)}")
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _, _}, %{ref: ref} = state) when is_reference(ref) do
    try_check_after_interval(state.check_for_updates, state.update_interval)
    {:noreply, %{state | ref: nil}}
  end

  def handle_info({:DOWN, ref, :process, _, _}, state) do
    Logger.warn("Unknown update task with reference (#{ref}) was shut down.")
    {:noreply, state}
  end

  defp try_check_after_interval(false, _), do: nil

  defp try_check_after_interval(true, interval) do
    Process.send_after(self(), :check_updates, interval)
  end
end
