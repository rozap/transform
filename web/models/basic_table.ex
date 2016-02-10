defmodule Transform.BasicTableMeta do
  defstruct [
    columns:      []
  ]

  defmodule Type do
    @behaviour Ecto.Type
    alias Transform.BasicTableMeta

    def type, do: :json

    def cast(%BasicTableMeta{} = state) do
      {:ok, state}
    end
    def cast(%{} = state)      do
      state = state
      |> Enum.map(fn
        {key, val} when is_atom(key) -> {key, val}
        {key, val} -> {String.to_atom(key), val}
      end)
      |> Enum.into(%{})
      {:ok, struct(BasicTableMeta, state)}
    end
    def cast(_other),           do: :error

    def load(value) do
      Poison.decode(value, as: BasicTableMeta)
    end

    def dump(value) do
      Poison.encode(value)
    end
  end
end


defmodule Transform.BasicTable do
  use Ecto.Model
  alias Transform.BasicTableMeta

  schema "basic_tables" do
    belongs_to :upload, Transform.Upload
    field :meta, Transform.BasicTableMeta.Type
    timestamps
  end

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, [:upload_id, :meta], [])
  end
end
