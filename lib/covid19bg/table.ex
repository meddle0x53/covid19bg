defmodule Covid19bg.Table do
  alias Covid19bg.Table.Column

  @table_borders %{
    top: "═",
    top_separator: "╤",
    top_left: "╔",
    top_right: "╗",
    bottom: "═",
    bottom_separator: "╧",
    bottom_left: "╚",
    bottom_right: "╝",
    left: "║",
    left_separator: "╟",
    right: "║",
    right_separator: "╢",
    horizontal_separator: "─",
    separator: "┼",
    vertical_separator: "│"
  }

  @default_padding 2

  @table_settings %{
    border_color: :white
  }

  def default_table_settings, do: @table_settings

  def iodata(rows, column_settings, table_settings \\ @table_settings) do
    header_data =
      column_settings
      |> Enum.map(fn %{title: title, key: key} -> {key, title} end)
      |> Enum.into(%{})

    row_data = sort_and_index_rows(rows)
    column_settings = compute_column_widths(column_settings, [header_data | row_data])

    [
      new_line(),
      table_header(column_settings, table_settings),
      data_row(header_data, column_settings, table_settings, true),
      Enum.map(row_data, &data_row(&1, column_settings, table_settings)),
      footer_row(row_data, column_settings, table_settings),
      table_footer(column_settings, table_settings),
      new_line()
    ]
  end

  defp new_line, do: "\n"

  defp colorize(nil), do: <<>>
  defp colorize(color), do: Kernel.apply(IO.ANSI, color, [])

  defp decolorize(nil), do: <<>>
  defp decolorize(_color), do: IO.ANSI.reset()

  defp border(type, color, width \\ 1) do
    [
      colorize(color),
      @table_borders
      |> Map.fetch!(type)
      |> List.duplicate(width),
      decolorize(color)
    ]
  end

  defp draw_borders(
         %{left: left, line: line, separator: separator, right: right},
         column_settings,
         table_settings
       ) do
    [
      border(left, table_settings.border_color),
      column_settings
      |> Enum.map(fn %Column{width: width} -> border(line, table_settings.border_color, width) end)
      |> Enum.join(Enum.join(border(separator, table_settings.border_color))),
      border(right, table_settings.border_color),
      new_line()
    ]
  end

  defp table_header(column_settings, table_settings) do
    border = %{left: :top_left, line: :top, separator: :top_separator, right: :top_right}
    draw_borders(border, column_settings, table_settings)
  end

  defp table_line_separator(column_settings, table_settings) do
    border = %{
      left: :left_separator,
      line: :horizontal_separator,
      separator: :separator,
      right: :right_separator
    }

    draw_borders(border, column_settings, table_settings)
  end

  defp table_footer(column_settings, table_settings) do
    border = %{
      left: :bottom_left,
      line: :bottom,
      separator: :bottom_separator,
      right: :bottom_right
    }

    draw_borders(border, column_settings, table_settings)
  end

  defp row(row_data, column_settings, table_settings, header) do
    row_text =
      row_data
      |> Enum.join(border(:vertical_separator, table_settings.border_color) |> Enum.join())

    result = [
      border(:left, table_settings.border_color),
      row_text,
      border(:right, table_settings.border_color),
      new_line()
    ]

    if header do
      result
    else
      [table_line_separator(column_settings, table_settings) | result]
    end
  end

  defp data_row(data_chunk, column_settings, table_settings, header \\ false) do
    column_settings
    |> Enum.map(fn %Column{width: width, align: align} = column_data ->
      [
        colorize(Map.get(column_data, if(header, do: :header_color, else: :color))),
        " ",
        data_chunk
        |> Map.get(column_data.key, "")
        |> to_string()
        |> (fn str ->
              Kernel.apply(
                String,
                if(align == :left, do: :pad_trailing, else: :pad_leading),
                [str, width - @default_padding]
              )
            end).(),
        " ",
        decolorize(Map.get(column_data, :color))
      ]
      |> Enum.join()
    end)
    |> row(column_settings, table_settings, header)
  end

  defp footer_row(data, column_settings, table_settings) do
    column_settings
    |> Enum.reduce(%{}, fn column_data, footer_data ->
      case List.first(data) do
        data_row when is_map(data_row) ->
          case Map.get(data_row, column_data.key) do
            number when is_number(number) ->
              value =
                data
                |> Enum.map(&Map.get(&1, column_data.key, 0))
                |> Enum.sum()

              if Map.get(column_data, :summary, true) do
                Map.put(footer_data, column_data.key, value)
              else
                footer_data
              end

            _ ->
              footer_data
          end

        _ ->
          footer_data
      end
    end)
    |> data_row(column_settings, table_settings)
  end

  defp sort_and_index_rows(data) do
    data
    |> Enum.sort(fn
      %{total: total1}, %{total: total2} when total1 > total2 -> true
      %{total: total1}, %{total: total2} when total1 < total2 -> false
      %{active: active1}, %{active: active2} when active1 > active2 -> true
      _, _ -> false
    end)
    |> Enum.with_index()
    |> Enum.map(fn {data_chunk, index} ->
      Map.put(data_chunk, :rank, index + 1)
    end)
  end

  defp compute_column_widths(column_settings, data) do
    column_settings
    |> Enum.map(fn column = %Column{key: key} ->
      width =
        data
        |> Enum.map(fn row ->
          row
          |> Map.get(key, "")
          |> case do
            number when is_integer(number) ->
              Number.Delimit.number_to_delimited(number)

            text ->
              text
          end
          |> String.length()
          |> Kernel.+(@default_padding)
          |> (&Map.put(row, :width, &1)).()
        end)
        |> Enum.max_by(& &1.width)
        |> Map.get(:width)

      %Column{column | width: width}
    end)
  end
end
