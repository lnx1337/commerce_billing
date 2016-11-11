defmodule Commerce.Billing.HttpRequest do
  defstruct [:method, :url, :headers, :body, :auth_mode, :credentials]
  
  alias Commerce.Billing.HttpRequest
  
  def new(method, url) do
    %HttpRequest{
      method: method,
      url: url,
      headers: [],
      auth_mode: :none
    }
  end
  
  def put_body(request, params, encoding) do
    con_type = content_type(encoding)
    
    request
      |> Map.put(:body, params_to_string(params))
      |> put_header(con_type)
  end
  
  def put_basic_auth(request, credentials) do
    request
      |> Map.put(:auth_mode, :basic)
      |> Map.put(:credentials, [hackney: [basic_auth: credentials]])
  end
  
  def send(request) do
    HTTPoison.request(
      request.method,
      request.url,
      request.body,
      request.headers,
      request.credentials)
  end
  
  defp put_header(request, header),
    do: Map.put(request, :headers, [header | request.headers])
  
  defp content_type(:url_encoded),
    do: {"Content-Type", "application/x-www-form-urlencoded"}
    
  defp params_to_string(params) do
    params
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> URI.encode_query
  end
end