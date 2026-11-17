# SPDX-FileCopyrightText: 2019 Frank Hunleth
# SPDX-FileCopyrightText: 2024 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetSupplicant.Daemon do
  @moduledoc """
  Start a `wpa_supplicant` and wait for its control files
  """

  @default_driver "nl80211,wext"

  @doc """
  Start a `wpa_supplicant` for an interface

  The daemon is linked to the calling process.

  Options:

  * `:wpa_supplicant` - the path to the wpa_supplicant binary. If `""`, nothing
    is started and `{:ok, nil}` is returned. This is for unit tests.
  * `:wpa_supplicant_conf_path` - the path to the supplicant's conf file
  * `:ifname` - the network interface
  * `:driver` - the wpa_supplicant driver(s) to use. Defaults to
    `"nl80211,wext"`. Use `"wired"` for wired Ethernet.
  * `:control_paths` - control files to erase before starting just in case
    they're left over from a previous run
  * `:verbose` - true to enable wpa_supplicant debug output
  """
  @spec start_link(keyword()) :: GenServer.on_start() | {:ok, nil}
  def start_link(opts) do
    case Keyword.fetch!(opts, :wpa_supplicant) do
      "" -> {:ok, nil}
      wpa_supplicant -> start_daemon(wpa_supplicant, opts)
    end
  end

  defp start_daemon(wpa_supplicant, opts) do
    ifname = Keyword.fetch!(opts, :ifname)
    conf_path = Keyword.fetch!(opts, :wpa_supplicant_conf_path)
    driver = Keyword.get(opts, :driver, @default_driver)
    verbose_flag = if Keyword.get(opts, :verbose, false), do: ["-dd"], else: []

    # Erase old control paths just in case they exist
    opts |> Keyword.get(:control_paths, []) |> Enum.each(&File.rm/1)

    # -i ifname      // which interface
    # -D driver      // e.g., nl80211,wext to try nl80211 first, then wext
    # -c config_file // use our config file
    # -dd            // verbose
    args = ["-i", ifname, "-D#{driver}", "-c", conf_path | verbose_flag]

    MuonTrap.Daemon.start_link(
      wpa_supplicant,
      args,
      VintageNet.Command.add_muon_options(stderr_to_stdout: true, log_output: :debug)
    )
  end

  @doc """
  Wait for the wpa_supplicant to create its control files

  This returns the paths that exist. It's empty on timeout.
  """
  @spec wait_for_control_files([Path.t()], integer()) :: [Path.t()]
  def wait_for_control_files(paths, time_left \\ 3000)

  def wait_for_control_files(_paths, time_left) when time_left <= 0 do
    []
  end

  def wait_for_control_files(paths, time_left) do
    case Enum.filter(paths, &File.exists?/1) do
      [] ->
        Process.sleep(250)
        wait_for_control_files(paths, time_left - 250)

      found_paths when length(found_paths) < length(paths) ->
        # It's not guaranteed that all paths are always created, so allow
        # this to work, but with a penalty just in case the others show up
        # momentarily.
        Process.sleep(100)
        Enum.filter(paths, &File.exists?/1)

      found_paths ->
        found_paths
    end
  end
end
