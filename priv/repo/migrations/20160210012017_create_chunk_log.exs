defmodule Transform.Repo.Migrations.CreateChunkLog do
  use Ecto.Migration

  def change do
    create table(:uploads) do
      timestamps
    end

    create table(:jobs) do
      add :upload_id, references(:uploads)
      add :dataset, :string
      add :source, :text
      timestamps
    end

    create table(:basic_tables) do
      add :job_id, references(:jobs)
      add :meta, :json
      timestamps
    end

    create table(:chunks) do
      add :basic_table_id, references(:basic_tables)
      add :location, :string
      add :sequence_number, :integer
      add :attempt_number, :integer, default: 0
      add :completed_at, :datetime
      add :completed_location, :string
      timestamps
    end

  end
end
