# SPDX-FileCopyrightText: 2024 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetSupplicant do
  @moduledoc """
  Shared `wpa_supplicant` support for VintageNet technologies

  This library runs and talks to a `wpa_supplicant` instance for a network
  interface. It's used by `vintage_net_wifi` for WiFi and by
  `vintage_net_ethernet` for wired IEEE 802.1X and MACsec. It's not a
  `VintageNet.Technology` itself.

  Technologies add `VintageNetSupplicant.WPASupplicant` to the `:child_specs`
  of their `VintageNet.Interface.RawConfig` and write the `wpa_supplicant`
  configuration file themselves.
  """
end
