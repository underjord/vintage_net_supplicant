# SPDX-FileCopyrightText: 2019 Frank Hunleth
# SPDX-FileCopyrightText: 2020 Connor Rigby
# SPDX-FileCopyrightText: 2024 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetSupplicant.WPASupplicant do
  @moduledoc """
  Run and monitor a `wpa_supplicant` for an interface

  This is for technologies that only need authentication, like wired IEEE
  802.1X. It starts the `wpa_supplicant`, keeps track of EAP status in the
  interface's `eap_status` property, and exits if the `wpa_supplicant` goes
  away. It knows nothing about WiFi. `vintage_net_wifi` has its own.
  """

  use GenServer

  alias VintageNet.Interface.EAPStatus
  alias VintageNetSupplicant.{Daemon, EAP, WPASupplicantDecoder, WPASupplicantLL}
  require Logger

  @doc """
  Start a GenServer to manage communication with a wpa_supplicant

  Arguments:

  * `:wpa_supplicant` - the path to the wpa_supplicant binary
  * `:wpa_supplicant_conf_path` - the path to the supplicant's conf file
  * `:ifname` - the network interface
  * `:control_path` - the directory with the wpa_supplicant control files
  * `:driver` - the wpa_supplicant driver(s) to use. Defaults to
    `"nl80211,wext"`. Use `"wired"` for wired Ethernet.
  * `:keep_alive_interval` - how often to ping the wpa_supplicant to
    make sure it's still alive (defaults to 60,000 milliseconds)
  * `:verbose` - true to enable wpa_supplicant debug output
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) do
    ifname = Keyword.fetch!(args, :ifname)
    GenServer.start_link(__MODULE__, args, name: via_name(ifname))
  end

  defp via_name(ifname) do
    {:via, Registry, {VintageNet.Interface.Registry, {__MODULE__, ifname}}}
  end

  @doc """
  Send a raw command to the `wpa_supplicant`

  This doesn't do any kind of processing on the results and just returns whatever
  `wpa_supplicant` says. See [ctrl_iface](https://w1.fi/wpa_supplicant/devel/ctrl_iface_page.html)
  and `ctrl_iface.c` for options.

      iex> VintageNetSupplicant.WPASupplicant.raw_command("eth0", "STATUS")
      {:ok, "wpa_state=COMPLETED\\n"}
  """
  @spec raw_command(VintageNet.ifname(), String.t()) :: {:ok, String.t()} | {:error, any()}
  def raw_command(ifname, command) do
    GenServer.call(via_name(ifname), {:raw_command, command})
  end

  @impl GenServer
  def init(args) do
    ifname = Keyword.fetch!(args, :ifname)
    control_dir = Keyword.fetch!(args, :control_path)

    state = %{
      ifname: ifname,
      control_path: Path.join(control_dir, ifname),
      keep_alive_interval: Keyword.get(args, :keep_alive_interval, 60000),
      eap_status: %EAPStatus{},
      ll: nil
    }

    {:ok, state, {:continue, {:start, args}}}
  end

  @impl GenServer
  def handle_continue({:start, args}, state) do
    {:ok, _daemon} = Daemon.start_link([control_paths: [state.control_path]] ++ args)

    case Daemon.wait_for_control_files([state.control_path]) do
      [path] ->
        {:ok, ll} = WPASupplicantLL.start_link(path: path, notification_pid: self())
        {:ok, "OK\n"} = WPASupplicantLL.control_request(ll, "ATTACH")

        # Clear out status from a previous run
        EAP.put_status_property(state.ifname, state.eap_status)

        {:noreply, %{state | ll: ll}, state.keep_alive_interval}

      [] ->
        raise RuntimeError,
              "Couldn't find wpa_supplicant control file: #{inspect(state.control_path)}"
    end
  end

  @impl GenServer
  def handle_call({:raw_command, command}, _from, state) do
    response = WPASupplicantLL.control_request(state.ll, command)
    {:reply, response, state, state.keep_alive_interval}
  end

  @impl GenServer
  def handle_info(:timeout, state) do
    case WPASupplicantLL.control_request(state.ll, "PING") do
      {:ok, <<"PONG", _rest::binary>>} ->
        {:noreply, state, state.keep_alive_interval}

      other ->
        raise "Bad PING response: #{inspect(other)}"
    end
  end

  def handle_info({WPASupplicantLL, _priority, message}, state) do
    notification = WPASupplicantDecoder.decode_notification(message)

    new_state = handle_notification(notification, state)
    {:noreply, new_state, new_state.keep_alive_interval}
  end

  defp handle_notification({:event, "CTRL-EVENT-EAP-STATUS", _info} = notification, state) do
    case EAP.update_status(state.eap_status, notification) do
      {:ok, eap_status} ->
        EAP.put_status_property(state.ifname, eap_status)
        %{state | eap_status: eap_status}

      :unknown ->
        state
    end
  end

  defp handle_notification({:event, "CTRL-EVENT-TERMINATING"}, _state) do
    exit(:wpa_supplicant_terminated)
  end

  defp handle_notification({:info, message}, state) do
    Logger.debug("wpa_supplicant(#{state.ifname}): #{message}")
    state
  end

  defp handle_notification(unhandled, state) do
    Logger.debug("WPASupplicant ignoring #{inspect(unhandled)}")
    state
  end
end
