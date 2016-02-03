defmodule Transform.PageController do
  use Transform.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
