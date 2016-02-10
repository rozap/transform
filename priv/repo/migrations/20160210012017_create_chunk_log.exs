defmodule Transform.Repo.Migrations.CreateChunkLog do
  use Ecto.Migration

  def change do
    create table(:uploads) do
      timestamps
    end

    create table(:basic_tables) do
      add :upload_id, references(:uploads)
      add :meta, :json
      timestamps
    end


    create table(:chunks) do
      add :basic_table_id, references(:basic_tables)
      add :location, :string
      add :sequence_number, :integer
      add :attempt_number, :integer, default: 0
      timestamps
    end

    create table(:transform_results) do
      add :chunk_id, references(:chunks)
      timestamps
    end
  end
end
