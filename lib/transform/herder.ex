defmodule Transform.Herder do
  require Logger
  use GenServer
  alias Transform.Repo
  alias Transform.Chunk
  import Ecto.Query

  @timeout 8 # Chunks orphaned for N seconds get retried
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


    orphaned_set = Repo.all(
      from c in Chunk,
      where:
        c.inserted_at < ^cutoff and
        c.attempt_number < @max_attempts and
        is_nil(c.completed_at),
      select: c
    )

    Enum.each(orphaned_set, fn chunk ->

      cset = Chunk.changeset(chunk, %{attempt_number: chunk.attempt_number + 1})

      Repo.update!(cset)

      basic_table = Repo.get!(Transform.BasicTable, chunk.basic_table_id)
      job = Repo.get!(Transform.Job, basic_table.job_id)
      Logger.info("Retrying orphaned chunk #{chunk.id} #{job.dataset}, #{chunk.attempt_number} attempt")
      Transform.Executor.Worker.push(
        job,
        basic_table,
        chunk
      )
    end)


    {:noreply, state}
  end

end