defmodule Proca.Stage.Support do
  @moduledoc """
  Support functions for job processing in Broadway. Most imporatntly functions
  to build RabbitMQ events containing enough data to be processed internally
  (system) or externally (custom).
  """

  alias Proca.{Action, Supporter, PublicKey, Contact, Field, Confirm}
  alias Proca.Repo
  import Ecto.Query, only: [from: 2]
  alias Broadway.Message

  # XXX for now we assume that only ActionPage owner does the processing, but i think it should be up to
  # the AP.delivery flag

  def bulk_actions_data(action_ids, stage \\ :deliver, org_id \\ nil) do
    from(a in Action,
      where: a.id in ^action_ids,
      preload: [
        [supporter: [contacts: [:public_key, :sign_key, :org]]],
        :action_page,
        :campaign,
        :source
      ]
    )
    |> Repo.all()
    |> Enum.map(fn a -> action_data(a, stage, org_id) end)
  end

  def action_data(action, stage \\ :deliver, org_id \\ nil) do 

    org_id = org_id || action.action_page.org_id

    contact =
      Enum.find(action.supporter.contacts, fn c -> c.org_id == org_id end)

    mod = case contact.org.action_schema_version do 
      1 -> Proca.Stage.MessageV1
      2 -> Proca.Stage.MessageV2 
    end
    apply(mod, :action_data, [action, stage, org_id])
  end

  def ignore(message = %Broadway.Message{}, reason \\ "ignored") do 
    message
    |> Message.configure_ack(on_failure: :ack)
    |> Message.failed(reason)
  end

  def to_iso8601(naivedatetime) do 
    naivedatetime
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
  end

  defp link_verb(:confirm), do: "accept"
  defp link_verb(:reject), do: "reject"

  def supporter_link(%Action{id: action_id, supporter: %{fingerprint: fpr}}, op) do 
    ref = Supporter.base_encode(fpr)

    ProcaWeb.Router.Helpers.confirm_url(ProcaWeb.Endpoint, :supporter, action_id, link_verb(op), ref)
  end

  def supporter_link(action_id, contact_ref, op) when is_integer(action_id) and is_bitstring(contact_ref) do 
    ProcaWeb.Router.Helpers.confirm_url(ProcaWeb.Endpoint, :supporter, action_id, link_verb(op), contact_ref)
  end

  def confirm_link(%Confirm{code: code, email: email}, op) when is_bitstring(code) and is_bitstring(email) do 
    ProcaWeb.Router.Helpers.confirm_url(ProcaWeb.Endpoint, :confirm, link_verb(op), code, email: email)
  end

  def confirm_link(%Confirm{code: code, object_id: id}, op) when is_bitstring(code) and is_number(id) do 
    ProcaWeb.Router.Helpers.confirm_url(ProcaWeb.Endpoint, :confirm, link_verb(op), code, id: id)
  end

  def confirm_link(%Confirm{code: code}, op) when is_bitstring(code) do 
    ProcaWeb.Router.Helpers.confirm_url(ProcaWeb.Endpoint, :confirm, link_verb(op), code)
  end

end
