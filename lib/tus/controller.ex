defmodule Tus.Controller do
  defmacro __using__(_) do
    quote do
      @allowed_methods ~w(OPTIONS HEAD PATCH DELETE)

      def options(conn, config \\ %{}) do
        call_method(conn, config)
      end

      def head(conn, %{"uid" => uid} = config) do
        call_method(conn, config |> Map.put(:uid, uid))
      end

      def post(conn, config \\ %{}) do
        call_method(conn)
      end

      def patch(conn, %{"uid" => uid} = config) do
        call_method(conn, config |> Map.put(:uid, uid))
      end

      def delete(conn, %{"uid" => uid} = config) do
        call_method(conn, config |> Map.put(:uid, uid))
      end

      def on_begin_upload(_file) do
        :ok
      end

      def on_complete_upload(_file) do
      end

      defoverridable on_begin_upload: 1, on_complete_upload: 1

      defp call_method(conn, config \\ %{}) do
        config = update_config(conn, config)
        conn = override_method(conn)

        call_versioned_method(
          conn.method |> String.downcase() |> String.to_atom(),
          conn,
          config
        )
      end

      defp update_config(conn, config) do
        app_env =
          Application.get_env(:tus, __MODULE__, [])
          |> Enum.into(%{})
          |> Map.put(:cache_name, Module.concat(__MODULE__, TusCache))
          |> Map.put(:version, get_version(conn))
          |> Map.put(:on_begin_upload, &on_begin_upload/1)
          |> Map.put(:on_complete_upload, &on_complete_upload/1)

        Map.merge(app_env, config)
      end

      defp get_version(conn) do
        Plug.Conn.get_req_header(conn, "tus-resumable") |> List.first()
      end

      def override_method(conn) do
        override_original_method(conn.method, conn)
      end

      defp override_original_method("POST", conn) do
        new_method = Plug.Conn.get_req_header(conn, "x-http-method-override") |> List.first()

        if new_method in @allowed_methods do
          %{conn | method: new_method}
        else
          conn
        end
      end

      defp override_original_method(_, conn), do: conn

      defp call_versioned_method(:options, conn, config) do
        Tus.options(conn, config)
      end

      defp call_versioned_method(_method, conn, %{version: nil}) do
        Plug.Conn.resp(conn, :bad_request, "API version not specified")
      end

      defp call_versioned_method(method, conn, config) do
        apply(Tus, method, [conn, config])
      end
    end
  end
end
