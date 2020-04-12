defmodule Covid19bg.Formatters.Text do
  alias Covid19bg.Table
  alias Covid19bg.Table.Column

  require Logger

  @column_settings [
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

  def format(source, use_ansi_colors \\ true) do
    do_format(source.retrieve(:by_places), source, use_ansi_colors)
  end

  defp do_format({:error, :no_recent_data}, source, use_ansi_colors) do
    Logger.warn("No recent data available to be displayed from #{source.description}!")

    do_format([], source, use_ansi_colors)
  end

  defp do_format(data, source, use_ansi_colors) do
    location = source.location()

    column_settings =
      Enum.map(@column_settings, fn column_data ->
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

    updated =
      case List.last(data) do
        nil -> DateTime.utc_now()
        %{updated: updated} -> updated
      end
      |> DateTime.shift_zone("Europe/Sofia")
      |> Kernel.elem(1)
      |> DateTime.to_iso8601()

    [
      Table.iodata(data, column_settings, table_settings),
      "\n",
      "Updated: ",
      colorize(:magenta, use_ansi_colors),
      updated,
      decolorize(use_ansi_colors),
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

  defp colorize(color, true), do: Kernel.apply(IO.ANSI, color, [])
  defp colorize(_, false), do: <<>>

  defp decolorize(true), do: IO.ANSI.reset()
  defp decolorize(false), do: <<>>
end
