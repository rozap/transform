defmodule Transform.Chunk do
  use Ecto.Model

  schema "chunks" do
    belongs_to :basic_table, Transform.BasicTable
    field :location, :string
    field :sequence_number, :integer
    field :attempt_number, :integer, default: 0
    field :completed_at, Ecto.DateTime
    field :completed_location, :string
    timestamps
  end

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, [], [:attempt_number, :completed_at, :completed_location])
  end
end
