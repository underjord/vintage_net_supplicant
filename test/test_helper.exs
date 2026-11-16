# SPDX-FileCopyrightText: 2019 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
File.rm_rf!("test_tmp")
File.mkdir_p!("test_tmp")

# Networking support has enough pieces that are singleton in nature
# that parallel running of tests can't be done.
ExUnit.start(max_cases: 1)
