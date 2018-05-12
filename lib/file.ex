defmodule Tus.File do
  @enforce_keys [:uid]

  defstruct uid: nil,
            size: nil,
            offset: 0,
            metadata_src: nil,
            metadata: %{},
            created_at: nil,
            path: nil,
            url: nil,
            upload_id: nil
end
