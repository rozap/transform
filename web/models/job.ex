defmodule Transform.Job do
  use Ecto.Model
  @noop "[]"

  schema "jobs" do
    field :dataset, :string
    has_one :upload, Transform.Upload
    field :source, :string, default: @noop
    timestamps
  end

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, [:dataset], [])
  end
end
