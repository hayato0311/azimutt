defmodule AzimuttWeb.Utils.ControllerHelpers do
  @moduledoc "Common code for controllers."
  use AzimuttWeb, :controller
  alias Azimutt.Accounts.User
  alias Azimutt.Organizations
  alias Azimutt.Organizations.Organization
  alias Azimutt.Organizations.OrganizationPlan

  def for_owners(conn, %Organization{} = organization, %User{} = current_user, exec) do
    if Organizations.owner?(organization, current_user) do
      exec.()
    else
      response_html(conn, organization, "You need Owner rights.")
    end
  end

  def for_writers_api(conn, %Organization{} = organization, %User{} = current_user, exec) do
    if Organizations.writer?(organization, current_user) do
      exec.()
    else
      response_json(conn, organization, "You need Writer rights.")
    end
  end

  def with_feature(conn, %Organization{} = organization, %OrganizationPlan{} = plan, feature, exec) do
    value = feature[plan.id]

    if is_boolean(value) && value do
      exec.()
    else
      response_html(conn, organization, "#{feature.name} not supported in #{plan.name} plan.")
    end
  end

  @doc "Best effort user facing message for any error shape, never fails: it's used in error paths."
  def to_message(%Ecto.Changeset{} = changeset), do: changeset |> changeset_errors() |> Enum.join(", ")
  def to_message({kind, message}) when is_atom(kind) and is_binary(message), do: message
  def to_message(message) when is_binary(message), do: message
  def to_message(message) when is_atom(message), do: message |> Atom.to_string() |> String.replace("_", " ")
  def to_message(err), do: inspect(err)

  # `traverse_errors` nests maps & lists for embeds and assocs, flatten them all to a list of strings
  defp changeset_errors(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} -> Enum.reduce(opts, msg, fn {key, value}, acc -> String.replace(acc, "%{#{key}}", to_string(value)) end) end)
    |> flatten_errors()
  end

  defp flatten_errors(errors) when is_map(errors), do: errors |> Enum.flat_map(fn {field, nested} -> nested |> flatten_errors() |> Enum.map(fn e -> "#{field} #{e}" end) end)
  defp flatten_errors(errors) when is_list(errors), do: errors |> Enum.flat_map(&flatten_errors/1)
  defp flatten_errors(error) when is_binary(error), do: [error]
  defp flatten_errors(error), do: [inspect(error)]

  defp response_html(conn, %Organization{} = organization, message),
    do: conn |> put_flash(:warn, message) |> redirect(to: Routes.organization_path(conn, :show, organization.id))

  defp response_json(conn, %Organization{} = _organization, message),
    do: conn |> put_status(:unauthorized) |> put_view(AzimuttWeb.ErrorView) |> render("error.json", %{message: message})
end
