defmodule MessengerWeb.PageController do
  use MessengerWeb, :controller

  def index(conn, _params) do
    conn

    |> put_resp_content_type("text/html")
    |> send_file(200, Application.app_dir(:messenger, "priv/static/index.html"))
  end
end