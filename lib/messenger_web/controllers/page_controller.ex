defmodule MessengerWeb.PageController do
  use MessengerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
