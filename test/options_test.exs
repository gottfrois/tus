defmodule Tus.OptionsTest do
  use ExUnit.Case, async: true
  use Plug.Test
  doctest Tus

  import Plug.Conn.Status, only: [code: 1]
  import Tus.TestHelpers, only: [test_conn: 2, get_config: 0]
  alias Tus.TestController

  setup_all do
    %{config: get_config()}
  end

  test "OPTIONS ignores the version and return all the required headers", context do
    config = context[:config]
    conn = test_conn(:options, %Plug.Conn{})
    response = TestController.options(conn)

    assert response.status == code(:no_content)
    assert response |> get_resp_header("tus-resumable") == [Tus.latest_version()]
    assert response |> get_resp_header("tus-version") == [Tus.str_supported_versions()]
    assert response |> get_resp_header("tus-max-size") == ["#{config.max_size}"]
    assert response |> get_resp_header("tus-extension") == [Tus.extension()]
  end

  test "unsupported version" do
    conn =
      test_conn(:post, %Plug.Conn{
        req_headers: [{"tus-resumable", "9999"}]
      })

    response = TestController.post(conn)

    assert response.status == Plug.Conn.Status.code(:precondition_failed)
    assert response |> get_resp_header("tus-resumable") == []
    assert response |> get_resp_header("tus-version") == [Tus.str_supported_versions()]
    assert response |> get_resp_header("tus-max-size") == []
    assert response |> get_resp_header("tus-extension") == []
  end

  test "method override" do
    original = "POST"
    target = "OPTIONS"

    conn =
      %Plug.Conn{
        method: original,
        req_headers: [
          {"x-http-method-override", target}
        ]
      }
      |> TestController.override_method()

    assert conn.method == target
  end

  test "invalid method to override" do
    original = "PATCH"
    target = "OPTIONS"

    conn =
      %Plug.Conn{
        method: original,
        req_headers: [
          {"x-http-method-override", target}
        ]
      }
      |> TestController.override_method()

    assert conn.method == original
  end

  test "invalid override target" do
    original = "POST"
    target = "GET"

    conn =
      %Plug.Conn{
        method: original,
        req_headers: [
          {"x-http-method-override", target}
        ]
      }
      |> TestController.override_method()

    assert conn.method == original
  end
end
