defmodule Tus.PostTest do
  use ExUnit.Case, async: true
  use Plug.Test
  doctest Tus.Post

  import Plug.Conn.Status, only: [code: 1]
  import Tus.TestHelpers, only: [test_conn: 2, get_config: 0]
  alias Tus.TestController

  setup_all do
    %{config: get_config()}
  end

  test "`HTTP 413 Request Entity Too Large` if upload larger than the hard config limit", context do
    config = context[:config]
    conn =
      test_conn(:post, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tus.latest_version()},
          {"upload-length", "#{config.max_size + 1}"}
        ]
      })

    response = TestController.post(conn)
    assert response.status == code(:request_entity_too_large)
  end

  test "`HTTP 413 Request Entity Too Large` if upload larger than a soft limit defined in the `Tus-Max-Size` header" do
    soft_limit = 1024

    conn =
      test_conn(:post, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tus.latest_version()},
          {"upload-length", "#{soft_limit + 1}"},
          {"tus-max-size", "#{soft_limit}"}
        ]
      })

    response = TestController.post(conn)
    assert response.status == code(:request_entity_too_large)
  end

  test "hard config limit override the `Tus-Max-Size` soft limit", context do
    config = context[:config]
    conn =
      test_conn(:post, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tus.latest_version()},
          {"upload-length", "#{config.max_size + 1}"},
          {"tus-max-size", "#{config.max_size + 10}"}
        ]
      })

    response = TestController.post(conn)
    assert response.status == code(:request_entity_too_large)
  end

  test "create a new upload", context do
    config = context[:config]
    size = 10

    conn =
      test_conn(:post, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tus.latest_version()},
          {"upload-length", "#{size}"}
        ]
      })

    response = TestController.post(conn)

    assert response.status == code(:created)
    assert response |> get_resp_header("tus-resumable") == [Tus.latest_version()]
    assert response |> get_resp_header("upload-offset") == []
    assert response |> get_resp_header("upload-length") == []

    location = response |> get_resp_header("location") |> List.first()
    assert location

    file = config.cache.get(config.cache_name, location |> Path.basename())
    assert file
    assert file.size == size

    File.rm_rf(config.base_path |> Path.expand())
  end

  test "parse metadata" do
    metadata_src = "filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,username YnJhaW4="

    expected = [
      {"filename", "world_domination_plan.pdf"},
      {"username", "brain"}
    ]

    assert Tus.Post.parse_metadata(metadata_src) == expected
  end

  test "parse metadata with invalid spaces" do
    metadata_src = "filename  d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg== , username YnJhaW4="

    expected = [
      {"filename", "world_domination_plan.pdf"},
      {"username", "brain"}
    ]

    assert Tus.Post.parse_metadata(metadata_src) == expected
  end

  test "create a new upload with metadata", context do
    config = context[:config]
    metadata_src = "filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,username YnJhaW4="

    conn =
      test_conn(:post, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tus.latest_version()},
          {"upload-length", "10"},
          {"upload-metadata", metadata_src}
        ]
      })

    uid =
      TestController.post(conn)
      |> get_resp_header("location")
      |> List.first()
      |> Path.basename()

    file = config.cache.get(config.cache_name, uid)

    expected = [
      {"filename", "world_domination_plan.pdf"},
      {"username", "brain"}
    ]

    assert file
    assert file.metadata_src == metadata_src
    assert file.metadata == expected

    File.rm_rf(config.base_path |> Path.expand())
  end

  test "on_begin_upload called", context do
    config = context[:config]
    TestController.post(
      test_conn(:post, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tus.latest_version()},
          {"upload-length", "10"}
        ]
      })
    )

    # https://dockyard.com/blog/2016/03/24/testing-function-delegation-in-elixir-without-stubbing
    assert_receive :on_begin_upload_called

    File.rm_rf(config.base_path |> Path.expand())
  end
end
