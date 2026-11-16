<!--
  SPDX-FileCopyrightText: 2024 Lars Wikman
  SPDX-License-Identifier: CC-BY-4.0
-->
# VintageNetSupplicant

Shared `wpa_supplicant` support for [VintageNet](https://github.com/nerves-networking/vintage_net)
technologies.

This is the `wpa_supplicant` process management, control socket and event
decoding code from
[`vintage_net_wifi`](https://github.com/nerves-networking/vintage_net_wifi),
pulled out so that `vintage_net_ethernet` can use it for wired IEEE 802.1X and
MACsec without depending on the WiFi library.

Extracted from `vintage_net_wifi` v0.12.12.

## Use

This is not a `VintageNet.Technology`. A technology writes the
`wpa_supplicant` configuration file and adds
`VintageNetSupplicant.WPASupplicant` to its raw config's child specs:

```elixir
%VintageNet.Interface.RawConfig{
  files: [{wpa_supplicant_conf_path, contents}],
  child_specs: [
    {VintageNetSupplicant.WPASupplicant,
     wpa_supplicant: "wpa_supplicant",
     ifname: ifname,
     driver: "wired",
     wpa_supplicant_conf_path: wpa_supplicant_conf_path,
     control_path: control_interface_dir}
  ]
}
```

`:driver` defaults to `"nl80211,wext"`.

## Installation

```elixir
def deps do
  [
    {:vintage_net_supplicant, github: "underjord/vintage_net_supplicant"}
  ]
end
```
