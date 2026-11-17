# SPDX-FileCopyrightText: 2024 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetSupplicant.WPASupplicantTest do
  use ExUnit.Case

  alias VintageNet.Interface.EAPStatus
  alias VintageNetSupplicant.WPASupplicant
  alias VintageNetSupplicantTest.MockWPASupplicant

  @ifname "test_eth0"
  @eap_property ["interface", @ifname, "eap_status"]

  setup do
    socket_path = "test_tmp/tmp_wpa_supplicant_socket"
    File.mkdir_p!(socket_path)

    mock = start_supervised!({MockWPASupplicant, Path.join(socket_path, @ifname)})
    MockWPASupplicant.set_responses(mock, %{"ATTACH" => "OK\n", "PING" => "PONG\n"})

    on_exit(fn ->
      _ = File.rm_rf(socket_path)
    end)

    PropertyTable.delete(VintageNet, @eap_property)
    VintageNet.subscribe(@eap_property)

    {:ok, socket_path: socket_path, mock: mock}
  end

  defp start_supplicant!(context, extra \\ []) do
    pid =
      start_supervised!(
        {WPASupplicant,
         [
           wpa_supplicant: "",
           wpa_supplicant_conf_path: "/dev/null",
           ifname: @ifname,
           driver: "wired",
           control_path: context.socket_path
         ] ++ extra}
      )

    # The property is reset once attached
    assert_receive {VintageNet, @eap_property, nil, %EAPStatus{status: nil}, _metadata}
    pid
  end

  test "attaches to wpa_supplicant", context do
    _ = start_supplicant!(context)

    assert MockWPASupplicant.get_requests(context.mock) == ["ATTACH"]
  end

  test "pings wpa_supplicant", context do
    _ = start_supplicant!(context, keep_alive_interval: 10)

    Process.sleep(100)
    assert "PING" in MockWPASupplicant.get_requests(context.mock)
  end

  test "sends raw commands", context do
    MockWPASupplicant.set_responses(context.mock, %{
      "ATTACH" => "OK\n",
      "STATUS" => "wpa_state=COMPLETED\n"
    })

    _ = start_supplicant!(context)

    assert {:ok, "wpa_state=COMPLETED\n"} == WPASupplicant.raw_command(@ifname, "STATUS")
  end

  test "tracks EAP status", context do
    _ = start_supplicant!(context)

    send_message = &MockWPASupplicant.send_message(context.mock, &1)

    send_message.("<3>CTRL-EVENT-EAP-STATUS status='started' parameter=''")
    assert_receive {VintageNet, @eap_property, _, %EAPStatus{status: :started}, _}

    send_message.("<3>CTRL-EVENT-EAP-STATUS status='accept proposed method' parameter='PEAP'")
    assert_receive {VintageNet, @eap_property, _, %EAPStatus{method: "PEAP"}, _}

    send_message.(
      "<3>CTRL-EVENT-EAP-STATUS status='remote certificate verification' parameter='success'"
    )

    assert_receive {VintageNet, @eap_property, _, %EAPStatus{remote_certificate_verified?: true},
                    _}

    send_message.("<3>CTRL-EVENT-EAP-STATUS status='completion' parameter='success'")

    assert_receive {VintageNet, @eap_property, _,
                    %EAPStatus{
                      status: :success,
                      method: "PEAP",
                      remote_certificate_verified?: true,
                      timestamp: %DateTime{}
                    }, _}
  end

  test "ignores WiFi notifications", context do
    pid = start_supplicant!(context)

    MockWPASupplicant.send_message(context.mock, "<2>CTRL-EVENT-BSS-ADDED 0 78:8a:20:87:7a:50")
    MockWPASupplicant.send_message(context.mock, "<2>CTRL-EVENT-SCAN-RESULTS ")

    assert {:ok, _} = WPASupplicant.raw_command(@ifname, "PING")
    assert Process.alive?(pid)
    assert MockWPASupplicant.get_requests(context.mock) == ["ATTACH", "PING"]
  end

  # wpa_supplicant asks for the private key passphrase when it cannot load the key, e.g. a
  # PKCS#11 URI without engine support. The request must not take the GenServer down.
  @tag :capture_log
  test "survives interactive requests", context do
    pid = start_supplicant!(context)
    ref = Process.monitor(pid)

    MockWPASupplicant.send_message(
      context.mock,
      "<3>CTRL-REQ-PASSPHRASE-0:Private key passphrase needed for SSID "
    )

    refute_receive {:DOWN, ^ref, :process, ^pid, _reason}, 200
    assert {:ok, _} = WPASupplicant.raw_command(@ifname, "PING")
  end

  @tag :capture_log
  test "exits when wpa_supplicant terminates", context do
    pid = start_supplicant!(context)
    ref = Process.monitor(pid)

    MockWPASupplicant.send_message(context.mock, "<3>CTRL-EVENT-TERMINATING ")
    assert_receive {:DOWN, ^ref, :process, ^pid, :wpa_supplicant_terminated}
  end
end
