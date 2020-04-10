defmodule Covid19bg.Table.Column do
  @enforce_keys [:title, :key]
  defstruct [
    :title,
    :key,
    summary: true,
    header_color: :red,
    color: nil,
    width: 0,
    align: :right
  ]
end
