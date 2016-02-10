defmodule Transform.TransformResult do
  use Ecto.Model

  schema "transform_results" do
    belongs_to :chunk, Transform.Chunk
    timestamps
  end

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, [], [])
  end
end
