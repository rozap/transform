defmodule Transform.Herder do
  require Logger
  use GenServer
  alias Transform.Repo
  alias Transform.TransformResult
  alias Transform.Chunk
  import Ecto.Query

  @timeout 10 # Chunks orphaned for N seconds get retried
  @max_attempts 4

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :timer.send_interval(@timeout * 1000, self, :tick)
    {:ok, %{}}
  end

  def handle_info(:tick, state) do
    now = :calendar.local_time

    cutoff = Calendar.DateTime.now_utc
    |> Calendar.DateTime.advance!(@timeout)

    completed_set = Repo.all(
      from tr in TransformResult,
      select: tr.chunk_id
    )

    orphaned_set = Repo.all(
      from c in Chunk,
      where:
        c.inserted_at < ^cutoff and
        c.attempt_number < @max_attempts and
        not (c.id in ^completed_set),
      select: c
    )

    Enum.each(orphaned_set, fn chunk ->

      cset = Chunk.changeset(chunk, %{attempt_number: chunk.attempt_number + 1})

      Repo.update!(cset)

      basic_table = Repo.get!(Transform.BasicTable, chunk.basic_table_id)
      upload = Repo.get!(Transform.Upload, basic_table.upload_id)
      Logger.info("Retrying orphaned chunk #{chunk.id} #{upload.dataset}, #{chunk.attempt_number} attempt")
      Transform.Executor.Worker.push(
        upload.dataset,
        basic_table,
        chunk
      )
    end)


    {:noreply, state}
  end

end