defmodule Transform.PageController do
  use Transform.Web, :controller

  def index(conn, params) do
    render(conn, "index.html", id: params["id"])
  end
end
