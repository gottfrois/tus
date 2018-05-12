defmodule DemoWeb.Router do
  use DemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DemoWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
  end

  scope "/files", DemoWeb do
    options "/", UploadController, :options
    match :head, "/:uid",   UploadController, :head
    post "/", UploadController, :post
    patch "/:uid",   UploadController, :patch
    delete "/:uid",   UploadController, :delete
  end

  # Other scopes may use custom stacks.
  # scope "/api", DemoWeb do
  #   pipe_through :api
  # end
end
