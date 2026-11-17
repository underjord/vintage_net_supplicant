# SPDX-FileCopyrightText: 2024 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule VintageNetSupplicant do
  @moduledoc """
  Shared `wpa_supplicant` support for VintageNet technologies

  This is the part of talking to a `wpa_supplicant` that isn't specific to
  WiFi:

  * `VintageNetSupplicant.Daemon` - start a `wpa_supplicant` for an interface
  * `VintageNetSupplicant.WPASupplicantLL` - the control socket
  * `VintageNetSupplicant.WPASupplicantDecoder` - decode control socket messages
  * `VintageNetSupplicant.EAP` - track EAP status
  * `VintageNetSupplicant.WPASupplicant` - a ready-to-use process built from
    the above for technologies that only need authentication, like wired IEEE
    802.1X

  `vintage_net_wifi` builds its own process from the first four. Everything
  about access points, scanning, mesh and WPS lives there.
  """
end
