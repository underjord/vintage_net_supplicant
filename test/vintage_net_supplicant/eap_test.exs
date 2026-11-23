# SPDX-FileCopyrightText: 2024 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetSupplicant.EAPTest do
  use ExUnit.Case

  alias VintageNet.Interface.EAPStatus
  alias VintageNetSupplicant.EAP

  defp event(info), do: {:event, "CTRL-EVENT-EAP-STATUS", info}

  test "updates status" do
    assert {:ok, %EAPStatus{status: :started, timestamp: %DateTime{}}} =
             EAP.update_status(%EAPStatus{}, event(%{"status" => "started", "parameter" => ""}))

    assert {:ok, %EAPStatus{status: :failure}} =
             EAP.update_status(
               %EAPStatus{status: :started},
               event(%{"status" => "completion", "parameter" => "failure"})
             )

    assert {:ok, %EAPStatus{remote_certificate_verified?: false}} =
             EAP.update_status(
               %EAPStatus{remote_certificate_verified?: true},
               event(%{"status" => "remote certificate verification", "parameter" => "failure"})
             )
  end

  test "requests for credentials are failures" do
    request = {:interactive, "CTRL-REQ-PIN", 0, "PIN needed for SSID "}

    assert {:ok, %EAPStatus{status: :failure, method: "TLS", timestamp: %DateTime{}}} =
             EAP.update_status(%EAPStatus{status: :started, method: "TLS"}, request)
  end

  test "ignores everything else" do
    assert :unknown == EAP.update_status(%EAPStatus{}, event(%{"status" => "something new"}))
    assert :unknown == EAP.update_status(%EAPStatus{}, {:event, "CTRL-EVENT-SCAN-STARTED"})
    assert :unknown == EAP.update_status(%EAPStatus{}, {:info, "hello"})
  end
end
