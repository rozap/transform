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

  def latest_for(dataset_id) do
    from j in __MODULE__,
      where: j.dataset == ^dataset_id,
      select: j,
      order_by: [desc: j.inserted_at]
  end
end
