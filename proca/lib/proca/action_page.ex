defmodule Proca.ActionPage do
  @moduledoc """
  Action Page belongs to a Campaign, and represents a page (widget) where members take action.

  Action Page accepts data in many formats (See Contact.Data) and produces Contact and Supporter records.
  """
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Proca.Repo
  alias Proca.{ActionPage, Campaign, Org}

  schema "action_pages" do
    field :locale, :string
    field :name, :string
    field :delivery, :boolean, default: true
    field :config, :map, default: %{}
    field :live, :boolean, default: false

    belongs_to :campaign, Proca.Campaign
    belongs_to :org, Proca.Org

    field :extra_supporters, :integer, default: 0

    field :thank_you_template_ref, :string

    timestamps()
  end

  @doc """
  Casts and validates values to change an Action Page.

  The name validation is a pattern that allows two styles of action names: 
  1. identifier/path1/path2/path3 - where identifiers and paths are alphanumeric + - _
  2. domain.com.pl/some/campaign - url style (very similar but _ is not allowed for domain part)
  See test/action_page_test.exs for examples of valid and invalid names
  """
  def changeset(action_page, params) do
    action_page
    |> cast(params, [
      :name,
      :locale,
      :extra_supporters,
      :delivery,
      :thank_you_template_ref,
      :config
    ])
    |> validate_required([:name, :locale, :extra_supporters])
    |> unique_constraint(:name)
    |> validate_format(
      :name,
      ~r/^([[:alnum:]-_]+|[[:alnum:]-]+(?:\.[[:alnum:]\.-]+)+)(?:\/[[:alnum:]_-]+)+$/
    )
  end

  def changeset(attrs) do
    changeset(%ActionPage{}, attrs)
  end

  def go_live(action_page) do 
    case action_page do 
      %{live: true} -> {:ok, action_page}
      %{live: false} -> 
        # XXX do the health checks! 
        change(action_page, live: true) |> Repo.update
    end
  end

  @doc """
  Upsert query of ActionPage by id or by name.

  org - what org does it belong to
  campaign - what campaign does it belong to
  attrs - attributes. The id and name will be tried in that order to lookup existing action page. If not found, it will be created.

  XXX what about live status ? probably the upsert API needs to have an optional live=true param
  """
  def upsert(org, campaign, attrs = %{id: id}) do
    (Repo.get_by(ActionPage,
       org_id: org.id,
       campaign_id: campaign.id,
       id: id
     ) || %ActionPage{})
    |> ActionPage.changeset(attrs)
    |> put_change(:campaign_id, campaign.id)
    |> put_change(:org_id, org.id)
  end

  def upsert(org, campaign, attrs = %{name: name}) do
    (Repo.get_by(ActionPage,
       org_id: org.id,
       campaign_id: campaign.id,
       name: name
     ) || %ActionPage{})
    |> ActionPage.changeset(attrs)
    |> put_change(:campaign_id, campaign.id)
    |> put_change(:org_id, org.id)
  end

  def upsert(org, campaign, attrs) do
    %ActionPage{}
    |> ActionPage.changeset(attrs)
    |> put_change(:campaign_id, campaign.id)
    |> put_change(:org_id, org.id)
  end

  def create_copy_in(org, ap, attrs) do
    ap = Repo.preload(ap, [:campaign])
    create(copy: ap, params: attrs, org: org, campaign: ap.campaign)
  end


  def create(kwlist) when is_list(kwlist), do: create(%ActionPage{}, kwlist)
  def create(ap, [{assoc, record} | kw]) when assoc == :campaign or assoc == :org, do: put_assoc(ap, assoc, record) |> create(kw)
  def create(ap, [{:params, attrs} | kw]), do: ActionPage.changeset(ap, attrs) |> create(kw)
  def create(ap, [{:copy, ap_tmpl} | kw]), do: change(ap, Map.take(ap_tmpl, [:config, :delivery, :locale])) |> create(kw)
  def create(ap, []), do: Repo.insert(ap)

  def find(id) when is_integer(id) do
    Repo.one from a in ActionPage, where: a.id == ^id, preload: [:campaign, :org]
  end

  def find(name) when is_bitstring(name) do
    Repo.one from a in ActionPage, where: a.name == ^name, preload: [:campaign, :org]
  end

  def contact_schema(%ActionPage{campaign: %Campaign{contact_schema: cs}}) do
    case cs do
      :basic -> Proca.Contact.BasicData
      :popular_initiative -> Proca.Contact.PopularInitiativeData
      :eci -> Proca.Contact.EciData
      :it_ci -> Proca.Contact.ItCiData
    end
  end

  def kept_personalization_fields(
        %ActionPage{
          campaign: campaign,
          org: org
        }
      ) do
    [:email, :first_name]
  end

  def new_data(params, action_page) do
    schema = contact_schema(action_page)
    apply(schema, :from_input, [params])
  end

  def name_domain(name) when is_bitstring(name) do 
    [d|_] = String.split(name, "/")
    d
  end

  def name_path(name) when is_bitstring(name) do 
    [_|p] = String.split(name, "/")
    p |> Enum.join("/")
  end

  # XXX deprecated url support
  def remove_schema_from_name(name) when is_bitstring(name) do
    Regex.replace(~r/^https?:\/\//, name, "")
  end
end
