defmodule DemoWeb.UploadController do
  use DemoWeb, :controller
  use Tus.Controller

  # start upload optional callback
  def on_begin_upload(file) do
    IO.puts "on_begin_upload"
    IO.inspect file
    IO.puts "------"
    :ok  # or {:error, reason} to reject the uplaod
  end

  # Completed upload optional callback
  def on_complete_upload(file) do
    IO.puts "on_complete_upload"
    IO.inspect file
    IO.puts "------"
  end
end
