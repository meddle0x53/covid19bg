defmodule Covid19bg.Formatters.Text do
  alias Covid19bg.API.Params
  alias Covid19bg.Table
  alias Covid19bg.Table.Column
  alias Covid19bg.Source.LocationData

  require Logger

  @by_place_column_settings [
    %Column{title: "Rank", key: :rank, summary: false, header_color: :red},
    %Column{title: "<location>", key: :place, align: :left, header_color: :red, color: :cyan},
    %Column{title: "Total", key: :total, header_color: :red, color: :yellow},
    %Column{
      title: "New",
      key: :total_new,
      header_color: :red,
      color: :cyan,
      formatter: &__MODULE__.formatter/2
    },
    %Column{title: "Total Deaths", key: :dead, header_color: :red, color: :red},
    %Column{
      title: "New Deaths",
      key: :dead_new,
      header_color: :red,
      color: :red,
      formatter: &__MODULE__.formatter/2
    },
    %Column{title: "Recovered", key: :recovered, header_color: :red, color: :green},
    %Column{
      title: "Newly Recovered",
      key: :recovered_new,
      header_color: :red,
      color: :green,
      formatter: &__MODULE__.formatter/2
    },
    %Column{title: "Active", key: :active, header_color: :red, color: :blue}
  ]

  @historical_column_settings [
    %Column{title: "Date", key: :updated, header_color: :green, align: :left},
    %Column{title: "Total cases", key: :total, header_color: :green, color: :yellow},
    %Column{title: "New cases", key: :total_new, header_color: :green, color: :yellow},
    %Column{title: "Total Deaths", key: :dead, header_color: :green, color: :red},
    %Column{title: "New Deaths", key: :dead_new, header_color: :green, color: :red},
    %Column{
      title: "Total Recovered",
      key: :recovered,
      header_color: :green,
      color: :green,
      remove_if: &__MODULE__.remove_broken/1
    },
    %Column{
      title: "New Recovered",
      key: :recovered_new,
      header_color: :green,
      color: :green,
      remove_if: &__MODULE__.remove_broken/1
    },
    %Column{
      title: "Hospitalized",
      key: :in_hospital,
      header_color: :green,
      color: :magenta,
      remove_if: &__MODULE__.remove_all_empty/1
    },
    %Column{
      title: "Critical",
      key: :critical,
      header_color: :green,
      color: :red,
      remove_if: &__MODULE__.remove_all_empty/1
    },
    %Column{title: "Active", key: :active, header_color: :green, color: :blue}
  ]

  def format(%Params{} = params, use_ansi_colors \\ true) do
    raw_data = params.source.retrieve(params.data_type, params.location)

    data =
      raw_data
      |> case do
        {:error, message} ->
          Logger.warn(message)
          []

        list when is_list(list) ->
          list
      end
      |> LocationData.sort_and_rank(params.order_keys)
      |> (fn list ->
            if params.order_direction == :asc do
              Enum.reverse(list)
            else
              list
            end
          end).()
      |> Enum.reject(fn %{summary: summary} -> summary end)
      |> Enum.drop(params.offset)
      |> Enum.take(params.limit)
      |> Kernel.++(Enum.filter(raw_data, fn %{summary: summary} -> summary end))

    case params.data_type do
      :by_places ->
        do_format(
          data,
          params.source,
          params.location,
          @by_place_column_settings,
          use_ansi_colors
        )

      :historical ->
        do_format(
          data,
          params.source,
          params.location,
          @historical_column_settings,
          use_ansi_colors
        )
    end
  end

  defp do_format({:error, :no_recent_data}, source, location, column_settings, use_ansi_colors) do
    Logger.warn(
      "No recent data available to be displayed for location #{location} from #{
        source.description
      }!"
    )

    do_format([], source, location, column_settings, use_ansi_colors)
  end

  defp do_format(data, source, location, columns, use_ansi_colors) do
    column_settings =
      Enum.map(columns, fn column_data ->
        %{column_data | title: String.replace(column_data.title, "<location>", location)}
      end)

    column_settings =
      if use_ansi_colors do
        column_settings
      else
        column_settings
        |> Enum.map(fn column_data ->
          %Column{column_data | color: nil, header_color: nil}
        end)
      end

    table_settings =
      if use_ansi_colors do
        Table.default_table_settings()
      else
        %{Table.default_table_settings() | border_color: nil}
      end

    updated_info =
      if columns == @by_place_column_settings do
        updated =
          case List.last(data) do
            nil -> DateTime.utc_now()
            %{updated: updated} -> updated
          end
          |> DateTime.shift_zone("Europe/Sofia")
          |> Kernel.elem(1)
          |> DateTime.to_iso8601()

        [
          "\n",
          "Updated: ",
          colorize(:magenta, use_ansi_colors),
          updated,
          decolorize(use_ansi_colors)
        ]
      else
        []
      end

    [
      Table.iodata(data, column_settings, table_settings),
      updated_info,
      "\n",
      "Source: ",
      colorize(:blue, use_ansi_colors),
      source.link(),
      decolorize(use_ansi_colors),
      colorize(:cyan, use_ansi_colors),
      " (",
      source.description(),
      ")",
      decolorize(use_ansi_colors),
      "\n"
    ]
  end

  def formatter(0, %{summary: false}), do: ""
  def formatter(v, _), do: to_string(v)

  def remove_all_empty(values) do
    Enum.all?(values, fn value -> value == "" || value == 0 || !value end)
  end

  def remove_broken(values) do
    Enum.any?(values, fn
      value when is_number(value) and value < 0 -> true
      value -> value
    end)
  end

  defp colorize(color, true), do: Kernel.apply(IO.ANSI, color, [])
  defp colorize(_, false), do: <<>>

  defp decolorize(true), do: IO.ANSI.reset()
  defp decolorize(false), do: <<>>
end
