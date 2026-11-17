# SPDX-FileCopyrightText: 2024 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetSupplicant.DaemonTest do
  use ExUnit.Case

  alias VintageNetSupplicant.Daemon

  test "doesn't start anything without a wpa_supplicant" do
    assert {:ok, nil} == Daemon.start_link(wpa_supplicant: "")
  end

  test "wpa_supplicant can't block on stdin" do
    dir = "test_tmp/daemon_stdin_test"
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    # A fake wpa_supplicant that reads stdin to the end and then says so
    done = Path.expand("done", dir)
    script = Path.expand("wpa_supplicant", dir)
    File.write!(script, "#!/bin/sh\ncat >/dev/null\ntouch #{done}\nsleep 10\n")
    File.chmod!(script, 0o755)

    {:ok, _pid} =
      Daemon.start_link(wpa_supplicant: script, ifname: "eth0", wpa_supplicant_conf_path: "x")

    assert [done] == Daemon.wait_for_control_files([done], 2000)
  end

  test "waits for control files" do
    dir = "test_tmp/daemon_test"
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    a = Path.join(dir, "a")
    b = Path.join(dir, "b")

    assert [] == Daemon.wait_for_control_files([a, b], 250)

    File.touch!(a)
    assert [a] == Daemon.wait_for_control_files([a, b], 250)

    File.touch!(b)
    assert [a, b] == Daemon.wait_for_control_files([a, b], 250)
  end
end
