# SPDX-FileCopyrightText: 2020 Connor Rigby
# SPDX-FileCopyrightText: 2024 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetSupplicant.EAP do
  @moduledoc """
  Track EAP status from `wpa_supplicant` notifications
  """
  alias VintageNet.Interface.EAPStatus

  @doc """
  Update an EAP status based on a decoded `wpa_supplicant` notification

  `CTRL-EVENT-EAP-STATUS` notifications update the status. A `CTRL-REQ-*`
  request is a failure: `wpa_supplicant` is asking for a credential, like a
  PIN or a private key passphrase, and waits for an answer that never comes
  since nothing responds to these requests.

  Returns `:unknown` for notifications that don't change the status.
  """
  @spec update_status(EAPStatus.t(), tuple()) :: {:ok, EAPStatus.t()} | :unknown
  def update_status(eap_status, {:event, "CTRL-EVENT-EAP-STATUS", info}) when is_map(info) do
    case changes(info) do
      nil -> :unknown
      changes -> {:ok, struct!(eap_status, [{:timestamp, DateTime.utc_now()} | changes])}
    end
  end

  def update_status(eap_status, {:interactive, "CTRL-REQ-" <> _field, _network_id, _text}) do
    {:ok, struct!(eap_status, timestamp: DateTime.utc_now(), status: :failure)}
  end

  def update_status(_eap_status, _notification), do: :unknown

  defp changes(%{"status" => "started"}), do: [status: :started]

  defp changes(%{"parameter" => method, "status" => "accept proposed method"}),
    do: [method: method]

  defp changes(%{"parameter" => "success", "status" => "remote certificate verification"}),
    do: [remote_certificate_verified?: true]

  defp changes(%{"parameter" => "failure", "status" => "remote certificate verification"}),
    do: [remote_certificate_verified?: false]

  defp changes(%{"parameter" => "failure", "status" => "completion"}), do: [status: :failure]
  defp changes(%{"parameter" => "success", "status" => "completion"}), do: [status: :success]
  defp changes(_other), do: nil

  @doc """
  Publish the EAP status to the interface's `eap_status` property
  """
  @spec put_status_property(VintageNet.ifname(), EAPStatus.t()) :: :ok
  def put_status_property(ifname, eap_status) do
    PropertyTable.put(VintageNet, ["interface", ifname, "eap_status"], eap_status)
  end
end
