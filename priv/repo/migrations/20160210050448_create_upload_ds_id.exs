defmodule Transform.Repo.Migrations.CreateUploadDsId do
  use Ecto.Migration

  def change do
    alter table(:uploads) do
      add :dataset, :text
    end
  end
end
