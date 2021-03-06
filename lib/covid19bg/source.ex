defmodule Covid19bg.Source do
  defmodule LocationData do
    defstruct active: 0,
              in_hospital: 0,
              critical: 0,
              recovered: 0,
              recovered_new: 0,
              area: "UNKNOWN",
              place: "UNKNOWN",
              place_code: "???",
              total: 0,
              total_new: 0,
              dead: 0,
              dead_new: 0,
              rank: 0,
              updated: DateTime.utc_now(),
              summary: false

    def sort_and_rank(list, fields \\ [:total, :active])

    def sort_and_rank(list, []), do: list

    def sort_and_rank([], _), do: []

    def sort_and_rank([%__MODULE__{} | _] = data, fields) do
      data
      |> Enum.reject(fn %{summary: summary} -> summary end)
      |> Enum.sort(fn data1, data2 ->
        fields
        |> Enum.drop_while(fn field ->
          Map.get(data1, field) == Map.get(data2, field)
        end)
        |> List.first()
        |> case do
          nil -> false
          field -> Map.get(data1, field) > Map.get(data2, field)
        end
      end)
      |> Enum.with_index()
      |> Enum.map(fn {data_chunk, index} ->
        Map.put(data_chunk, :rank, index + 1)
      end)
      |> Kernel.++(Enum.filter(data, fn %{summary: summary} -> summary end))
    end

    def add_summary([], parent_location) do
      [
        %__MODULE__{
          area: parent_location,
          place: parent_location,
          rank: "",
          updated: DateTime.from_unix!(0),
          summary: true
        }
      ]
    end

    def add_summary([%__MODULE__{} | _] = data, parent_location) do
      data
      |> Enum.reduce(
        %__MODULE__{area: parent_location, place: parent_location, rank: ""},
        fn location_data, summary ->
          %__MODULE__{
            active: active,
            recovered: recovered,
            total: total,
            total_new: total_new,
            dead_new: dead_new,
            dead: dead,
            updated: updated
          } = location_data

          %__MODULE__{
            active: active_summary,
            recovered: recovered_summary,
            total: total_summary,
            total_new: total_new_summary,
            dead: dead_summary,
            dead_new: dead_new_summary,
            updated: updated_summary
          } = summary

          %__MODULE__{
            summary
            | active: active + active_summary,
              recovered: recovered + recovered_summary,
              total: total + total_summary,
              total_new: total_new + total_new_summary,
              dead: dead + dead_summary,
              dead_new: dead_new + dead_new_summary,
              updated:
                if(DateTime.compare(updated, updated_summary) == :gt,
                  do: updated,
                  else: updated_summary
                )
          }
        end
      )
    end
  end
end
