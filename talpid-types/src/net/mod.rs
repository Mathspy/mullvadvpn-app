#[cfg(target_os = "android")]
use jnix::IntoJava;
use serde::{Deserialize, Serialize};
use std::{
    fmt,
    net::{IpAddr, SocketAddr},
    str::FromStr,
};

pub mod openvpn;
pub mod proxy;
#[cfg(feature = "wireguard")]
pub mod wireguard;

/// TunnelParameters are used to encapsulate all the data needed to start a tunnel. This is enum
/// should be generated by implementations of the trait
/// `talpid-core::tunnel_state_machine::TunnelParametersGenerator`
#[derive(Clone, Eq, PartialEq, Deserialize, Serialize, Debug)]
pub enum TunnelParameters {
    OpenVpn(openvpn::TunnelParameters),
    #[cfg(feature = "wireguard")]
    Wireguard(wireguard::TunnelParameters),
}


impl TunnelParameters {
    pub fn get_tunnel_endpoint(&self) -> TunnelEndpoint {
        match self {
            TunnelParameters::OpenVpn(params) => TunnelEndpoint {
                tunnel_type: TunnelType::OpenVpn,
                endpoint: params.config.endpoint,
                proxy: params.proxy.as_ref().map(|proxy| proxy.get_endpoint()),
                entry_endpoint: None,
            },
            #[cfg(feature = "wireguard")]
            TunnelParameters::Wireguard(params) => TunnelEndpoint {
                tunnel_type: TunnelType::Wireguard,
                endpoint: params
                    .connection
                    .get_exit_endpoint()
                    .unwrap_or(params.connection.get_endpoint()),
                proxy: None,
                entry_endpoint: params
                    .connection
                    .get_exit_endpoint()
                    .map(|_| params.connection.get_endpoint()),
            },
        }
    }

    // Returns the endpoint that will be connected to
    pub fn get_next_hop_endpoint(&self) -> Endpoint {
        match self {
            TunnelParameters::OpenVpn(params) => params
                .proxy
                .as_ref()
                .map(|proxy| proxy.get_endpoint().endpoint)
                .unwrap_or(params.config.endpoint),
            #[cfg(feature = "wireguard")]
            TunnelParameters::Wireguard(params) => params.connection.get_endpoint(),
        }
    }

    // Returns the exit endpoint, if it differs from the next hop endpoint
    pub fn get_exit_hop_endpoint(&self) -> Option<Endpoint> {
        match self {
            TunnelParameters::OpenVpn(_params) => None,
            #[cfg(feature = "wireguard")]
            TunnelParameters::Wireguard(params) => params.connection.get_exit_endpoint(),
        }
    }

    pub fn get_generic_options(&self) -> &GenericTunnelOptions {
        match &self {
            TunnelParameters::OpenVpn(params) => &params.generic_options,
            #[cfg(feature = "wireguard")]
            TunnelParameters::Wireguard(params) => &params.generic_options,
        }
    }
}

#[cfg(feature = "wireguard")]
impl From<wireguard::TunnelParameters> for TunnelParameters {
    fn from(wg_params: wireguard::TunnelParameters) -> TunnelParameters {
        TunnelParameters::Wireguard(wg_params)
    }
}

impl From<openvpn::TunnelParameters> for TunnelParameters {
    fn from(params: openvpn::TunnelParameters) -> TunnelParameters {
        TunnelParameters::OpenVpn(params)
    }
}

/// The tunnel protocol used by a [`TunnelEndpoint`].
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename = "tunnel_type")]
pub enum TunnelType {
    #[serde(rename = "openvpn")]
    OpenVpn,
    #[cfg(feature = "wireguard")]
    #[serde(rename = "wireguard")]
    Wireguard,
}

impl fmt::Display for TunnelType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> Result<(), fmt::Error> {
        let tunnel = match self {
            TunnelType::OpenVpn => "OpenVPN",
            #[cfg(feature = "wireguard")]
            TunnelType::Wireguard => "WireGuard",
        };
        write!(f, "{}", tunnel)
    }
}

/// A tunnel endpoint is broadcast during the connecting and connected states of the tunnel state
/// machine.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[cfg_attr(target_os = "android", derive(IntoJava))]
#[cfg_attr(target_os = "android", jnix(package = "net.mullvad.talpid.net"))]
pub struct TunnelEndpoint {
    #[serde(flatten)]
    pub endpoint: Endpoint,
    #[cfg_attr(target_os = "android", jnix(skip))]
    pub tunnel_type: TunnelType,
    #[cfg_attr(target_os = "android", jnix(skip))]
    pub proxy: Option<proxy::ProxyEndpoint>,
    #[cfg_attr(target_os = "android", jnix(skip))]
    pub entry_endpoint: Option<Endpoint>,
}

impl fmt::Display for TunnelEndpoint {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> Result<(), fmt::Error> {
        write!(f, "{} - {}", self.tunnel_type, self.endpoint)?;
        match self.tunnel_type {
            TunnelType::OpenVpn => {
                if let Some(ref proxy) = self.proxy {
                    write!(
                        f,
                        " via {} {} over {}",
                        proxy.proxy_type, proxy.endpoint.address, proxy.endpoint.protocol
                    )?;
                }
            }
            #[cfg(feature = "wireguard")]
            TunnelType::Wireguard => {
                if let Some(ref entry_endpoint) = self.entry_endpoint {
                    write!(f, " via {}", entry_endpoint)?;
                }
            }
        }
        Ok(())
    }
}


/// Represents a network layer IP address together with the transport layer protocol and port.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[cfg_attr(target_os = "android", derive(IntoJava))]
#[cfg_attr(target_os = "android", jnix(package = "net.mullvad.talpid.net"))]
pub struct Endpoint {
    /// The socket address for the endpoint
    pub address: SocketAddr,
    /// The protocol part of this endpoint.
    pub protocol: TransportProtocol,
}

impl Endpoint {
    /// Constructs a new `Endpoint` from the given parameters.
    pub fn new(address: impl Into<IpAddr>, port: u16, protocol: TransportProtocol) -> Self {
        Endpoint {
            address: SocketAddr::new(address.into(), port),
            protocol,
        }
    }

    pub fn from_socket_address(address: SocketAddr, protocol: TransportProtocol) -> Self {
        Endpoint { address, protocol }
    }
}

impl fmt::Display for Endpoint {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> Result<(), fmt::Error> {
        write!(f, "{} over {}", self.address, self.protocol)
    }
}

/// IP protocol version.
#[derive(Debug, Copy, Clone, Eq, PartialEq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum IpVersion {
    V4,
    V6,
}

impl Default for IpVersion {
    fn default() -> IpVersion {
        IpVersion::V4
    }
}

impl fmt::Display for IpVersion {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> Result<(), fmt::Error> {
        match *self {
            IpVersion::V4 => "IPv4".fmt(f),
            IpVersion::V6 => "IPv6".fmt(f),
        }
    }
}

/// Representation of a transport protocol, either UDP or TCP.
#[derive(Debug, Copy, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
#[cfg_attr(target_os = "android", derive(IntoJava))]
#[cfg_attr(target_os = "android", jnix(package = "net.mullvad.talpid.net"))]
pub enum TransportProtocol {
    /// Represents the UDP transport protocol.
    Udp,
    /// Represents the TCP transport protocol.
    Tcp,
}

impl FromStr for TransportProtocol {
    type Err = TransportProtocolParseError;

    fn from_str(s: &str) -> std::result::Result<TransportProtocol, Self::Err> {
        match s {
            "udp" => Ok(TransportProtocol::Udp),
            "tcp" => Ok(TransportProtocol::Tcp),
            _ => Err(TransportProtocolParseError),
        }
    }
}

impl fmt::Display for TransportProtocol {
    fn fmt(&self, fmt: &mut fmt::Formatter<'_>) -> fmt::Result {
        match *self {
            TransportProtocol::Udp => "UDP".fmt(fmt),
            TransportProtocol::Tcp => "TCP".fmt(fmt),
        }
    }
}


/// Returned when `TransportProtocol::from_str` fails to convert a string into a
/// [`TransportProtocol`] object.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TransportProtocolParseError;

impl fmt::Display for TransportProtocolParseError {
    fn fmt(&self, fmt: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt.write_str("Not a valid transport protocol")
    }
}

/// Holds optional settings that can apply to different kinds of tunnels
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Hash)]
pub struct GenericTunnelOptions {
    /// Enable configuration of IPv6 on the tunnel interface, allowing IPv6 communication to be
    /// forwarded through the tunnel.
    pub enable_ipv6: bool,
}

/// Returns a vector of IP networks representing all of the internet, 0.0.0.0/0.
/// This may be used in [`crate::net::wireguard::PeerConfig`] to route all traffic
/// to the tunnel interface.
pub fn all_of_the_internet() -> Vec<ipnetwork::IpNetwork> {
    vec![
        "0.0.0.0/0".parse().expect("Failed to parse ipv6 network"),
        "::0/0".parse().expect("Failed to parse ipv6 network"),
    ]
}
