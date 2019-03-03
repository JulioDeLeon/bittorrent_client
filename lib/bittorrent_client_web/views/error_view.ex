defmodule BittorrentClientWeb.ErrorView do
  use BittorrentClientWeb, :view
  alias Phoenix.Controller, as: PheonixController

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.html", _assigns) do
  #   "Internal Server Error"
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    PhoenixController.status_message_from_template(template)
  end
end
