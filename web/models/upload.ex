defmodule Transform.Upload do
  use Ecto.Model

  schema "uploads" do
    field :dataset, :string
    timestamps
  end

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, [:dataset], [])
  end
end
