# Network Configuration for ${bridge_name}
# Managed by Terraform - DO NOT EDIT MANUALLY

<% unless bond_slaves.empty? %>
# Bond Interface
auto bond0
iface bond0 inet manual
    bond-slaves <%= bond_slaves %>
    bond-mode <%= bond_mode %>
    bond-miimon <%= bond_miimon %>
    <% unless bond_lacp_rate.nil? || bond_lacp_rate.empty? %>bond-lacp-rate <%= bond_lacp_rate %><% end %>
<% end %>

# Bridge Interface
auto <%= bridge_name %>
iface <%= bridge_name %> inet static
    address <%= bridge_cidr %>
    <% unless bridge_gateway.nil? || bridge_gateway.empty? %>gateway <%= bridge_gateway %><% end %>
    bridge-ports <%= bridge_ports %>
    bridge-stp <%= bridge_stp %>
    bridge-fd <%= bridge_fd %>
    <% if vlan_aware %>bridge-vlan-aware yes<% end %>
    mtu <%= mtu %>
    <% unless autostart.nil? || !autostart %>auto <%= bridge_name %><% end %>
