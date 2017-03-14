# foreman-nic-provisioning

This is a script intended to be called by [Foreman](https://theforeman.org/) to setup a baremetal server with network bonding.  It can be used as a stand-alone script or as part of provisioning.  You could call it from a Kickstart file like this:

```
/usr/local/bin/mkbond.sh -I <%= @host.ip %> -G <%= @host.subnet.gateway %> -N <%= @host.subnet.mask %> -V <%= @host.subnet.vlanid %>
```

This script makes several assumptions:

* You are using only 2 NICs for bonding.
* You are doing active-backup bonding.
* You are using VLAN tagging.
* There are caveats built in to the script for specific hardware vendors.

This script is pretty specific due to our environment but it may give you an idea on how you can setup something similar for your environment.
