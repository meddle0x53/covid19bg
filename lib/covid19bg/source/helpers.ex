defmodule Covid19bg.Source.Helpers do
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
end
