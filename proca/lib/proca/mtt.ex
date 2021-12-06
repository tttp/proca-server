defmodule Proca.MTT do
  use Ecto.Schema
  use Proca.Schema, module: __MODULE__

  schema "mtt" do
    field :start_at, :utc_datetime
    field :end_at, :utc_datetime
    field :sending_rate, :integer
    field :stats, :map, default: %{}

    belongs_to :campaign, Proca.Campaign
  end

  def changeset(mtt, attrs) do
    assocs = Map.take(attrs, [:campaign])

    mtt
    |> cast(attrs, [:start_at, :end_at, :sending_rate, :stats])
    |> validate_required([:start_at, :end_at, :sending_rate])
    |> change(assocs)
  end
end
