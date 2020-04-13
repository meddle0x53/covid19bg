defmodule Covid19bg.Source.Helpers do
  @cities %{
    "Veliko Tarnovo" => "Велико Търново",
    "Kyustendil" => "Кюстендил",
    "Ruse" => "Русе",
    "Smolyan" => "Смолян",
    "Sofia City" => "София",
    "Plovdiv" => "Пловдив",
    "Burgas" => "Бургас",
    "Blagoevgrad" => "Благоевград",
    "Varna" => "Варна",
    "Stara Zagora" => "Стара Загора",
    "Pazardzhik" => "Пазарджик",
    "Kardzhali" => "Кърджали",
    "Dobrich" => "Добрич",
    "Sliven" => "Сливен",
    "Pleven" => "Плевен",
    "Haskovo" => "Хасково",
    "Pernik" => "Перник",
    "Shumen" => "Шумен",
    "Montana" => "Монтана",
    "Vratsa" => "Враца",
    "Vidin" => "Видин",
    "Silistra" => "Силистра",
    "Lovech" => "Ловеч",
    "Gabrovo" => "Габрово"
  }

  @cities_reverse @cities |> Enum.map(fn {k, v} -> {v, k} end) |> Enum.into(%{})

  def http_request(%URI{} = uri, transform_response, method \\ :get)
      when is_function(transform_response, 1) do
    with {:ok, response} <- Mojito.request(method: method, url: to_string(uri)),
         {:ok, data} <- transform_response.(response) do
      data
    else
      error ->
        error
    end
  end

  def cities_latin_cyrillic, do: @cities
  def cities_cyrillic_latin, do: @cities_reverse
end
