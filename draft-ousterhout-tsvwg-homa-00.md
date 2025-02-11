---
###
# Internet-Draft Markdown Template
#
# Rename this file from draft-todo-yourname-protocol.md to get started.
# Draft name format is "draft-<yourname>-<workgroup>-<name>.md".
#
# For initial setup, you only need to edit the first block of fields.
# Only "title" needs to be changed; delete "abbrev" if your title is short.
# Any other content can be edited, but be careful not to introduce errors.
# Some fields will be set automatically during setup if they are unchanged.
#
# Don't include "-00" or "-latest" in the filename.
# Labels in the form draft-<yourname>-<workgroup>-<name>-latest are used by
# the tools to refer to the current version; see "docname" for example.
#
# This template uses kramdown-rfc: https://github.com/cabo/kramdown-rfc
# You can replace the entire file if you prefer a different format.
# Change the file extension to match the format (.xml for XML, etc...)
#
###
title: "Homa: An RPC Transport Protocol for Datacenters"
abbrev: "Homa"
category: info

docname: draft-ousterhout-tsvwg-homa
submissiontype: IETF  # also: "independent", "editorial", "IAB", or "IRTF"
number:
date:
consensus: true
v: 3
area: AREA
workgroup: TSVWG Working Group
keyword:
 - next generation
 - unicorn
 - sparkling distributed ledger
venue:
  group: TSVWG
  type: Working Group
  mail: WG@example.com
  arch: https://example.com/WG
  github: USER/REPO
  latest: https://example.com/LATEST

author:
 -
    fullname: John Ousterhout
    organization: Stanford University
    email: ouster@cs.stanford.edu

normative:
  RFC9293:

informative:
  RFC791:
  RFC8200:
  ReplaceTCP:
    title: "It's Time to Replace TCP in the Datacenter"
    author:
      - name: John Ousterhout
        org: Stanford University
    date: January, 2023
    target:
      https://arxiv.org/abs/2210.00714

  Homa:
    title: "Homa: A Receiver-Driven Low-Latency Transport Protocol Using
           Network Priorities"
    author:
      - name: Benham Montazeri
        org: Stanford University
      - name: Yilong Li
        org: Stanford University
      - name: Mohammad Alizadeh
        org: MIT
      - name: John Ousterhout
        org: Stanford University
    seriesinfo:
      Proc. ACM SIGCOMM 2018, pp. 221–235
    date:
      August 2018
    target:
      https://dl.acm.org/doi/10.1145/3230543.3230564

  HomaLinux:
    title: "A Linux Kernel Implementation of the Homa Transport Protocol"
    author:
      - name: John Ousterhout
        ins: J. Ousterhout
        org: Stanford University
    seriesinfo:
      2021 USENIX Annual Technical Conference (USENIX ATC '21), pp. 773–787
    date:
      July 2021
    target:
      https://www.usenix.org/system/files/atc21-ousterhout.pdf


--- abstract

This document defines the Homa transport protocol. Homa provides
applications with a reliable and efficient mechanism for delivering
request and response messages for remote procedure calls (RPCs).
It is intended for use within datacenters and provides significant
performance improvements over TCP in this environment.

--- middle

# Introduction

Homa is a general-purpose transport protocol for use within datacenters.
It is intended for applications that use remote procedure calls (RPCs),
in which a request message is sent from a client to a
server, followed by a response message returned from the server back to the
client. Homa handles the delivery of the messages and also detects
server failures.

Homa differs from TCP [RFC9293] in almost every major aspect of its design:

* Homa implements messages instead of byte streams.

* Homa is connectionless.

* Homa manages flow control and congestion from the receiver, not
  the sender, and does not depend on buffer occupancy as a signal
  for congestion.

* Homa does not require in-order packet delivery.

The combination of all of these features allows Homa to achieve
significantly higher performance than TCP in datacenter environments.

Note: Homa is not suitable for use in WANs or other environments with
high latency. Homa is designed under the assumption of round-trip
times of a few tens of microseconds or less.

This document defines version 1 of Homa.

## Background

In spite of its long and successful history, TCP is a mediocre transport
protocol for modern datacenters. Every significant element
of TCP, from its stream orientation to its expectation
of in-order packet delivery, is wrong for the datacenter [ReplaceTCP].
Applications using TCP cannot achieve the full performance
potential of modern datacenter networking.

Homa is a clean-slate redesign of network transport for applications
running in datacenters.
As a result, Homa provides lower latency than TCP across a wide range
of message
lengths and workloads. Its benefits are greatest for short
messages in mixed workloads running at high network utilization:
lab experiments show 10-100x reduction in tail latency under
these conditions [HomaLinux].

See [Homa] for more on the rationale for Homa, the original design
of Homa (which differs somewhat from the protocol described here) and
early performance measurements. [HomaLinux] describes the first
implementation of Homa in Linux, with additional performance
measurements.

## Homa Summary

This section contains a brief overview of the key features of Homa. The
features will be discussed in more detail in later sections.

* Homa ensures reliable and flow-controlled delivery of messages for RPCs.
  For each RPC it delivers a request message from the client to the server
  and a response from the server back to the client.

* Homa is connectionless. Alternatively, each RPC can be thought of as
  a lightweight and short-lived connection that lasts until the RPC response
  has been received by the client.

* There is no ordering among Homa RPCs. Each RPC is processed independently,
  so RPCs may not complete in the same order they were initiated.

* Flow control in Homa is driven from receivers, not senders. Short messages
  may be transmitted in their entirety by senders without any flow control.
  Longer messages are divided into an initial *unscheduled* portion followed
  by a *scheduled* portion. The unscheduled portion of the message may be
  transmitted unilaterally by the sender, but the receiver
  controls the transmission of the scheduled portion by sending *grants*.

* Homa prioritizes shorter messages over longer ones. Specifically, it
  attempts to approximate SRPT (Shortest Remaining Processing Time first),
  which favors messages with fewer bytes remaining to transmit.
  It does this in several ways:

  * Homa takes advantage of the priority queues in datacenter switches,
    arranging for shorter messages to use higher-priority queues.
    The receiver of a message determines the priority for each incoming
    packet of the message (including unscheduled packets).

  * When multiple messages are inbound to a single receiver, the
    receiver uses grants to prioritize shorter messages.

  * When transmit queues build on senders, they use SRPT to prioritize outgoing
    packets. In order to prevent NIC queue buildup, which would damage
    SRPT, Homa endpoints generally need to implement packet pacing.

* The packets for a message may be delivered out of order, and receivers
  MUST reassemble out-of-order messages without requiring
  retransmission. Homa encourages the use of packet spraying for load
  balancing in the switching fabric.

* Homa receivers are responsible for detecting lost packets and
  requesting retransmission.

* Homa implements "at most once semantics" for RPCs. Among other things,
  this means that the server for an RPC must retain its state for that
  RPC until the client has received the response message. Homa implements
  an *acknowledgment* mechanism where clients (eventually) inform servers
  that it is safe for them to reclaim RPC state.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

Commonly used terms in this document are described below (alphabetical
order).

**Acknowledgment:**
: A token sent from an RPC's client to its server, indicating that it
  is safe for the server to delete its state for the RPC. There are no
  packet-level acknowledgments in Homa.

**Client:**
: An entity that initiates a Homa RPC: it sends a request message and
receives the response. This term may refer to either the
application that initiates the RPC or to the corresponding Homa endpoint.

**Common Header:**
: The initial bytes of each packet, which have the same format in all
packets regardless of type.

**Endpoint:**
: An entity that implements the Homa protocol, typically associated with
a single network link on a given machine. Endpoints can act as both
client and server.

**Grant:**
: A token issued by the receiver for a message, which entitles the
  message sender to transmit all of the bytes of the message up to a
  given offset. The grant also specifies the priority to use in
  the message's data packets.

**Homa:**
: The transport protocol described by this document. Homa is a name,
  not an acronym.

**Incoming:**
: Number of bytes of data in a message that have been authorized to be
  transmitted but have not yet been received. Data is authorized if it is
  within the unscheduled region of a message or if the receiver has
  transmitted a `GRANT` packet for it. Data is considered "incoming"
  even if the sender has not yet received the grant and/or the data has
  not yet been transmitted.

**Maximum Transmission Unit (MTU):**
: The maximum allowable size for a network packet, including all headers.

**Message:**
: The unit of communication that Homa provides to applications.
A message consists of a fixed-length array of bytes ranging in length from a
single byte up to a system-defined upper limit. There are two kinds
of messages in Homa: requests and responses.

**Packet:**
: The unit of transmission between Homa endpoints. Each packet has one
of several types and consists of a type-specific header followed
optionally by part or all of the data for a single message.

**Priority:**
: A value in the range \[0-7\], which is included in transmitted packets
  and used by network switches to select a priority queue at the
  egress port for the packet.
  Switches should be configured to transmit higher-priority packets in
  preference to lower-priority ones.

**Remote Procedure Call (RPC):**
: The primary abstraction implemented by Homa, consisting of a request
message sent from client to server, followed by a response message
returned from the server back to the client.

**Rpcid:**
: An integer that uniquely identifies a given RPC among all of the
RPCs initiated from the same endpoint. The pair <endpoint address, rpcid>
provides a system-wide unique identifier for a Homa RPC. Rpcids are
always even and increase sequentially in order of creation on the
client.

**Scheduled Data:**
: The remainder of a message after the unscheduled data. Transmission
  of scheduled data is controlled by the receiver issuing
  grant packets.

**Server:**
: An entity that receives a Homa request and sends the corresponding
response. This term may refer to either an application program or the
corresponding Homa endpoint.

**SRPT (Shortest Remaining Pressing Time):**
: Homa tries to prioritize messages that have the fewest remaining
  bytes to transmit, both on the sender side and the receiver side.

**TCP Segmentation Offload (TSO):**
: A hardware feature implemented by most NICs, which allows host
software to process outgoing network data in units larger than
the network MTU. With TSO, the host generates *TSO frames*,
which look like packets that exceed the MTU. The NIC divides
each TSO frame into multiple smaller packets (*segments*) for
transmission. In this document the term "packet" always refers
to the entities transmitted on the wire, not TSO frames.

**Top of Rack Switch (TOR):**
: The network switches at the edges of the datacenter switching
  fabric. Individual hosts connect to TORs.

**Unscheduled Data:**
: The initial portion of a message, which may be transmitted
  unilaterally by the sending without waiting for permission
  from the receiver.

# Packet Formats

Homa endpoints communicate with packets that are transmitted using an
unreliable datagram protocol such as IPv4 [RFC791] or IPv6 [RFC8200].
Each packet has a *type* that determines how the packet is processed.
A packet has two parts:

* A *common header*, which has the same format in all packets,
regardless of type.

* Aditional information that is type-specific. Some packet types have
no type-specific information.

The structure of the common header is specified in {{commonHdr}};
it closely mirrors the structure
of TCP headers [RFC9293] in order to allow Homa to take advantage
of TCP Segmentation Offload (TSO) implemented by many NICs.

~~~
    0                   1                   2                   3
    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |          Source Port          |       Destination Port        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                             Offset                            |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                    Reserved                   |     Type      |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |  Doff |       Reserved        |            Reserved           |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |           Checksum            |         Urgent Pointer        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                             Rpcid (high)                      |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                             Rpcid (low)                     |S|
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
~~~
{: #commonHdr title="Common header format"}

The fields in the common header are as follows:

**Source Port:**
: Identifier that corresponds to an application-level entity on the
the machine that sent the packet.

**Destination Port:**
: Identifier that corresponds to an application-level entity on the
the machine that receives the packet.

**Offset:**
: Used only for DATA packets, and only under conditions described
below; contains the offset within the message of the first byte
of data in the packet.

**Type:**
: Type of this packet. Must have one of the following values:

~~~
     DATA         16
     GRANT        17
     RESEND       18
     RPC_UNKNOWN  19
     BUSY         20
     CUTOFFS      21
     NEED_ACK     23
     ACK          24
~~~

**Doff:**
: Corresponds to the Data Offset field in TCP. Only used by senders
in order to ensure correct TSO behavior; MUST NOT be used by Homa receivers.

**Checksum:**
: Corresponds to the Checksum field in TCP. Not used by Homa, but may
be modified by NICs during TSO.

**Urgent Pointer:**
: Corresponds to the Urgent Pointer in TCP. Set by Homa during TCP
hijacking to enable receviers to distinguish Homa-over-TCP packets
from genuine TCP packets.

**Rpcid:**
: Associates the packet with a particular RPC.

**S:**
: If the low-order bit of the Rpcid is 0 it means that the packet was sent
by the client for the RPC; 1 means it was sent by the server.

## DATA packets {#secDataPkt}

The structure of a Homa data packet is specified by {{dataPkt}} below:

~~~
    0                   1                   2                   3
    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                         Common Header                         |
   |                               .                               |
   |                               .                               |
   |                               .                               |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                         Message Length                        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                           Incoming                            |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                           Ack Rpcid (high)                    |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                           Ack Rpcid (low)                     |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |        Ack Server Port        |         Cutoff Version        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |    Retrans    |                    Reserved                   |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                             Offset                            |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                         Message Data                          |
   |                               .                               |
   |                               .                               |
   |                               .                               |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
~~~
{: #dataPkt title="Format of DATA packets"}

A data packet contains part or all of the payload for a message.
It MUST start with a common header whose `Type` is `DATA` and whose `Rpcid`
specifies the RPC that the data is associated with.
If the `S` bit is set in the common header then this
packet contains data for the response message of the RPC; otherwise it
contains data for the request.
The following fields follow the common header:

**Message Length:**
: The total length of the message in bytes. This MUST be the same in
every data packet for the message.

**Incoming:**
: The total number of initial bytes of the message that the sender
will transmit without receiving additional grants.

**Ack Rpcid:**
: Identifies another RPC for which the sender is client and the receiver is
server, whose response message has been fully received by the client.
Indicates that the server can safely reclaim any state for that RPC.
A value of 0 indicates that no RPC is being acknowledged.
See {{secAcks}} below for details on acknowledgments.

**Ack Server Port:**
: The port number (on the server) to which `Ack Rpcid` was sent.

**Cutoff Version:**
: The version number for the priority cutoffs currently used
on the sender for this receiver. See {{secUnsched}} below for details.

**Retrans:**
: If this byte is nonzero it means the packet was sent in response
to a `RESEND` packet.

**Offset:**
: Offset within the message of the first byte of data contained in
this packet.

**Message Data:**
: Partial or complete contents of the message. The amount of data
is determined by the length of the packet. This field is OPTIONAL.

In the simplest case, an RPC requires two `DATA` packets. The first one
contains the entire request; it is transmitted from client to server and
has an `S` bit of zero and a zero `Offset`. The second packet is transmitted
from server to client; it has an `S` bit of one, and a zero `Offset`.

## GRANT packets {#secGrantPkt}

`GRANT` packets are used to manage network queue lengths when multiple
senders attempt to send messages to the same destination. The structure of
a grant packet is specified by {{grantPkt}} below:

~~~
    0                   1                   2                   3
    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                         Common Header                         |
   |                               .                               |
   |                               .                               |
   |                               .                               |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                             Offset                            |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |    Priority   |   Resend All  |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
~~~
{: #grantPkt title="Format of GRANT packets"}

A `GRANT` packet contains a common header followed by the following fields:

**Offset:**
: The recipient of the `GRANT` packet is now entitled to transmit all of the
data in the message given by the `Rpcid` common header field up to (but not
including this offset).

**Priority:**
: The recipient should use the value of this field as the priority in all
future `DATA` packets transmitted for this message.

**Resend All:**
: If this field is non-zero, then the recipient should resend the entire
message starting at the beginning, up to `Offset`.

## RESEND packets {#secResendPkt}

A Homa endpoint sends `RESEND` packets when message data that it is expecting
to receive is overdue and likely lost. The structure of a `RESEND` packet is
specified by {{resendPkt}} below:

~~~
    0                   1                   2                   3
    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                         Common Header                         |
   |                               .                               |
   |                               .                               |
   |                               .                               |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                             Offset                            |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                             Length                            |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |    Priority   |
   +-+-+-+-+-+-+-+-+
~~~
{: #resendPkt title="Format of RESEND packets"}

A `RESEND` packet contains a common header followed by the following fields:

**Offset:**
: The offset within the message of the first byte of data to retransmit.

**Length:**
: The number of bytes to retransmit.

**Priority:**
: The priority to use for all packets retransmitted in response to
this request.

## RPC_UNKNOWN packets {#secUnknownPkt}

A Homa endpoint sends a packet with type `RPC_UNKNOWN` when it receives a
`RESEND` packet with an Rpcid that is uknonwn to it (i.e. the endpoint
has no outbound message for that Rpcid). An `RPC_UNKNOWN` packet consists of
a common header with no additional information.

*This description needs work: `RPC_UNKNOWN` packets should only be issued by
clients, and it's unclear that these packets are needed at all (replace
with `ACK`s or just ignore?).*

## BUSY packets {#secBusyPkt}

Packets with type `BUSY` are sent by servers when they receive a
`RESEND` packet for the response message but the response message is
not yet ready, either because the request has not been fully received
or because the application has not yet generated a response.
`BUSY` packets are not sent by clients.
A `BUSY` packet consists entirely of the common header.

## CUTOFFS packets {#secCutoffsPkt}

Packets with type `CUTOFFS` specify how the recipient should
assign priorities for unscheduled packets in the future
(see {{secUnsched}} for details). The structure of
a `CUTOFFS` packet is specified by {{cutoffsPkt}} below:

~~~
    0                   1                   2                   3
    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                         Common Header                         |
   |                               .                               |
   |                               .                               |
   |                               .                               |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                           Cutoffs[0]                          |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                           Cutoffs[1]                          |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                              ...                              |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                           Cutoffs[7]                          |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |         Cutoff Version        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
~~~
{: #cutoffsPkt title="Format of CUTOFFS packets"}

A `CUTOFFS` packet contains a common header followed by the following fields:

**Cutoffs:**
: An array of 8 monotonically nonincreasing 32-bit values. The priority for an
unscheduled `DATA` packet sent from the `CUTOFFS` recipient to its sender
MUST be the largest `i` such that `Cutoffs[i]` is greater than or
equal to the length
of the packet's message. Entry 0 in `Cutoffs` must be greater than or
equal to the largest allowable message length.

**Cutoff Version:**
: Identfies this particular choice of cutoffs; the `CUTOFFS` recipient
MUST include this value as the `Cutoff Version` in all
future `DATA` packets sent to the `CUTOFFS` sender (allows the sender to
detect when cutoffs need to be updated).

## NEED_ACK packets {#secNeedAckPkt}

A `NEED_ACK` packet is sent from the server for an RPC to the client.
It indicates that the server has transmitted all of the data in the
response message for `Rpcid` and would like to reclaim its state for
that RPC. However, it cannot do so until the client has acknowledged
receiving the entire response. If the client is no longer waiting for
the indicated Rpcid (or if the Rpcid is unknown), it MUST respond with
an `ACK` packet that includes the Rpcid. If the client has not yet
received the full response, it need not respond to the `NEED_ACK` packet
(but it SHOULD issue a `RESEND` for any unreceived bytes).

The structure of a `NEED_ACK` packet consists of a common header with
no additional information.

## ACK packets {#secAckPkt}

An `ACK` packet is sent from a client to a server.  It acknowledges that
the server can safely reclaim state for one or more RPCs.
The structure of an `ACK` packet is specified by {{ackPkt}} below:

~~~
    0                   1                   2                   3
    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                         Common Header                         |
   |                               .                               |
   |                               .                               |
   |                               .                               |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |            Num_Acks           |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                           Ack Rpcid (high)                    |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                           Ack Rpcid (low)                     |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |          Server Port          |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                             Rpcid (high)                      |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                             Rpcid (low)                       |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |          Server Port          |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   . . .
~~~
{: #ackPkt title="Format of ACK packets"}

An `ACK` packet can acknowledge multiple RPCs. First, it acknowledges the
RPC identified by the `Rpcid` and `Server Port` fields of the common header.
It also acknowleldges additional RPCs specified with information following
the common header:

**Num_Acks:**
: Indicates how many additional acknowledgments follow after this field.

**Ack Rpcid:**
: Identifies an RPC with the following properties:

    * The source of the `ACK` packet was the client for the RPC and the
    target of the `ACK` packet was its server.

    * The RPC's response message has been fully received by the client.

    * Or, the `Ack Rpcid` was received in a `NEED_ACK` message but was unknown
    to the client.

**Ack Server Port:**
: The server port associated with `Ack Rpcid`.

# Policy Considerations for Grants {#secGrants}

The policy for issuing grants (which messages to grant at any given time and
how much to grant to each message) involves complex considerations and has
a significant impact on message latency and throughput, network link
utilization, buffer occupancy in network switches, and packet drops.

The basic lifecycle of a message is as follows:

* The message sender transmits one or more packets containing unscheduled
  data. It is possible for the amount of unscheduled data in a message to
  be zero; in this case the sender transmits a `DATA` packet containing
  no data (but it will indicate the message length).

* Once the first `DATA` packet has been received, the receiver begins
  issuing grants for the scheduled bytes of the message.

* As grants arrive at the sender, it transmits additional data packets. As
  these packets are received, the receiver issues additional grants, until
  eventually the entire message has been transmitted.

## Achieving high throughput

At any given time there is a range of bytes in a message that have been
granted but not yet been received. The number of bytes in this range is
referred to as the *incoming* for the message. A byte is considered to
have been granted once the `GRANT` packet has been transmitted by the
receiver,  even if the grant has not yet been received by the sender and/or
the packet containing the byte has not been transmitted by the sender.
Unscheduled data has been implicitly granted, so it is included in the
message's incoming as soon as the first `DATA` packet arrives at the receiver.

The term *total incoming* refers to the sum of the incomings of all messages
known to an endpoint.

In order for a message to achieve the full throughput of the network, its
incoming must always be at least as large as the bandwidth-delay product (BDP)
for a packet roundtrip. The relevant bandwidth for BDP
is that of the network links connecting hosts and top-of-rack switches
(TORs); this discussion assumes for simplicity that all host-TOR uplinks
have the same bandwidth. The delay for BDP must include all software
overheads in addition to delays in the network hardware.
For example, delay can be measured on the sender as the time
from when the first `DATA` packet for a message is passed to the NIC until
the packet
has been received and processed by software on the receiver, a `GRANT`
packet is issued by the receiver, the `GRANT` is received and processed
by software on the sender, and a subsequent `DATA` packet has been
passed to the NIC. On the receiver, delay can be measured as the time
from when Homa software receives a `DATA` packet until a new `GRANT`
has been transmitted, the `GRANT` has been received and processed by
software on the sender, a `DATA` packet  authorized by the `GRANT`
has been transmitted, and that packet has been received by Homa software
on the receiver.

The round-trip time for BDP is dominated by software overheads.  For example,
the network hardware contribution to round-trip time can be as low as 5 μs,
but the total round-trip time including software is likely to be at least
15-20 μs in the best case on unloaded servers [HomaLinux]. Software overheads
are affected significantly by server load (e.g., hot spots can cause large
delays in servicing incoming packets). On servers
with moderate loads, median round-trip times are likely to be at least
30-50 μs, with 99th-percentile times of 100-300 μs [HomaLinux].
If we assume a round-trip time of 100 μs in order to ensure consistently
high throughput under load, with a link speed of 100 Gbps, then the
incoming for a message (and also the amount of unscheduled data) must
be at least 1.25 Mbytes. As discussed below, buffer occupancy
considerations may make this amount impractical.

## SRPT and Overcommitment

Grants play an important role in implementing SRPT. If a receiver has
multiple inbound messages, it MUST use grants to prioritize messages
with fewer remaining bytes to transmit.

The simplest approach is to issue grants only to the highest priority
message, allowing that message to consume its entire link bandwidth. Then,
once the highest priority message is completely granted, the receiver can
issue grants to the next higher priority message, and so on. If a new
message begins arriving and has fewer remaining bytes than the current
highest priority message, then the receiver stops granting to the previous
message and begins granting to the new message.

Unfortunately a one-message-at-a-time approach will result in wasted
link bandwidth. The problem is that a sender may also have multiple
outbound messages. If it has grants for more than one of them, then it
will dedicate its uplink bandwidth to the highest priority message.
Thus, when a receiver issues a grant it cannot be certain that the
sender will transmit the granted bytes immediately. If a receiver
only grants to one message and that message's sender chooses not to
transmit the message, then there will be a "bubble" on
the receiver's downlink where its bandwidth is not utilized, even
though there might be other inbound messages that could use the bandwidth.
Measurements in [Homa] indicate that a one-message-at-a-time approach
wastes about 40% of the link bandwidth in mixed workloads.

In order to maximize link bandwidth utilization, receivers SHOULD
*overcommit* their downlinks; that is, they should maintain outstanding
grants for more than one message at a time. With this approach, even if
some senders choose not to transmit, other senders can use the available
link bandwidth. A degree of overcommitment of 4-8 seems adequate in practice.

Overcommitment has two potential negative consequences. The first is that
it potentially weakens SRPT: if the highest-priority sender is willing to
transmit, there may be packets from lower-priority messages that compete
for the downlink bandwidth, thereby reducing the throughput for the
high-priority message. This problem is solved by using priorities, as
discussed in {{secPriorities}}.

The second problem with overcommitment is that it increases buffer
occupancy in the network switch. If a receiver grants to multiple inbound
messages and all of their senders transmit, the aggregate bandwidth of
transmission will exceed the bandwidth of the receiver's downlink, so
packets will be buffered at the egress port in the TOR. The amount of
buffer space occupied will equal the total incoming across all of the
receiver's inbound messages, less one BDP. Thus, the
more messages a receiver grants to, the more buffer space will be
consumed in the TOR (assuming total incoming increases with the degree
of overcommitment). Buffer management is discussed in {{secBuffers}}.

## One message per endpoint

Under normal conditions, a Homa endpoint SHOULD only issue grants to a
single message from a given endpoint. If a receiver grants to multiple
messages from the same endpoint, the sender will only transmit the higher
priority of the two messages; if the sender has some other message to a
different destination that is even higher priority, then it will not
transmit either of the two lower-priority messages. Thus there is no
point in granting to a second message from the same endpoint; better to
use that grant for a message from a different endpoint, even if it is
lower priority.

However, as network speeds increase it may make sense for a receiver
to grant to multiple messages from the same endpoint. This is because
it is becoming increasingly difficult for a single message to consume
all of the outbound bandwidth of a network link. For example, the
bandwidth for copying data from user space into nework packets
has been measured at 30-40 Gbps on some machines; this is inadequate
to support a 100 Gbps link. When this occurs, it may make sense to
grant to multiple messages from the same endpoint in order to ensure
full usage of the sender's uplink.

## FIFO grants

The SRPT policy has been shown to result in low latencies across almost
all message lengths [Homa] [HomaLinux]. Although the latency benefits are
greatest for short messages, Homa also reduces latencies for
long messages when compared to the "fair sharing" approach used in TCP.
This is because SRPT results in "run to completion" behavior. Once a
message becomes highest priority, it will remain highest priority until
it completes (unless a new message with higher priority arrives) so it
will finish quickly.  In contrast, fair sharing will split the available
network bandwidth across all of the inbound messages, so all of the
inbound messages finish slowly. This is similar to a phenomenon
observed in process scheduling: when there are many CPU-bound processes,
FIFO scheduling results in lower average completion time than round-robin.

In principle it is possible that SRPT could result in starvation for the
longest inbound message, if there are enough shorter messages to fully
utilize the link bandwidth. This is unlikely to occur in practice, though,
since network links are rarely driven at 100% capacity; lab experiments
have found it difficult to generate starvation even with adversarial
workloads.

To eliminate any possibility of starvation, a receiver MAY reserve a
small fraction of its link bandwidth for grants to the oldest inbound
message rather than the highest priority one.  A FIFO fraction of about
5% seems adequate to eliminate starvation even under pathological
conditions.

# Priorities and Cutoffs {#secPriorities}

Homa uses the priority queues in modern data center switches to implement
SRPT. A sender can specify a priority in each outbound packet (for example,
using the high-order bits of the DSCP field in IPv4 or the high-order bits
of the Traffic Class field in IPv6).
Network switches can be configured to use the priority value in a packet
to place the packet in one of several queues at the switch egress port.
Switches can also be configured to serve the egress queues in strict
priority order, so that higher-priority packets are transmitted before
lower-priority packets. This section describes how Homa uses packet
priorities.

## Scheduled packets

Each `GRANT` packet contains a Priority field, which the sender MUST use
for all subsequent packets in the associated message until the next
`GRANT` is received. The receiver thus
has direct control over the priority for each scheduled packet. When a
receiver grants to multiple inbound messages at once, it SHOULD assign
a different priority for each message (highest priority for the message
with the least remaining bytes to transmit). This ensures that when
multiple senders transmit simultaneously and the receiver's TOR link
is overcommitted, packets from the highest priority message will be
transmitted and packets for other messages will be queued in the TOR.
If the highest-priority sender chooses not to transmit its message,
then packets from other messages will get through to the receiver.
The use of priorities allows Homa to achieve "perfect" SRPT even when
overcommitting its TOR link.

## Unscheduled packets {#secUnsched}

For unscheduled packets the receiver must assign packet priorities in
advance. It does this by analyzing recent incoming traffic and
assigning unscheduled priorities based on message length (shorter messages
receive higher priorities). A collection of "cutoffs" identifies the
message lengths that separate different priority
levels. Each receiver communicates its cutoffs to senders using `CUTOFF`
packets. Senders retain information about the cutoffs for each
endpoint that they communicate with, and use that information to choose
priorities for unscheduled packets.

A version number is associated with the cutoff information for each
endpoint. A receiver SHOULD occasionally update its cutoffs to reflect
changes in traffic patterns and when it does so it MUST assign a new
version number for the new cutoffs.  The version number is included in
`CUTOFFS` packets, saved on senders, and included in `DATA`
packets from the sender to the corresponding receiver. Each time a
data packet is received, the receiver MUST check the Cutoff
Version in the packet; if it is out of date, the receiver MUST
send a new `CUTOFFS` packet to update the sender.

Homa endpoints SHOULD assign unscheduled priorities so that each
priority level is used for about the same number of incoming bytes.
First, an endpoint can use recent traffic statistics to compute the
total fraction of incoming bytes that are unscheduled. The available
priority levels SHOULD be divided between unscheduled packets and
scheduled packets using this fraction; e.g., if 75% of incoming bytes
are unscheduled, then 75% of available priority levels SHOULD be used
for unscheduled packets and 25% of available priority levels SHOULD be
used for scheduled packets. The highest priority levels MUST be
assigned to unscheduled packets. At least one priority level MUST be
available for each of unscheduled and scheduled packets, but the
lowest unscheduled priority level MAY also be used as the highest
scheduled priority level.

Once the number of unscheduled priority levels is known, the cutoffs
between unscheduled priorities SHOULD be chosen so that each priority
level is used for the same amount of traffic (based on recent traffic
patterns). Higher priority levels go to shorter messages.

## How many priority levels?

Measurements suggest that 4 priority levels is enough to produce
good performance and additional priority levels beyond 4
provide little benefit [HomaLinux]. Homa can operate with a single
priority level and still provide better latency than
TCP, though additional priority levels provide significant latency
improvements.

## Priorities and overcommitment

The number of priority levels assigned for scheduled packets need
not be the same as the degree of overcommitment. Suppose that an
endpoint is currently granting to M inbound messages and there
are S scheduled
priority levels. If M > S, then the S-1 highest priority messages
SHOULD each use a dedicated priority level and the M-(S-1) lowest
priority messages SHOULD share the lowest scheduled priority level.
If M < S, then the M lowest scheduled priorities SHOULD be used for
grants (reserving the highest priority levels allows faster
preemption if new higher-priority messages arrive).

## Control packets

All packets other than `DATA` packets SHOULD use the highest available
priority level in order to minimize the delays experienced by these
packets. It is particularly important for `GRANT` packets to have high
priority in order to minimize control lag and maximize throughput.

## Priorities and the switching fabric

Packet priorities are most useful at the egress ports of TOR switches,
since this is where congestion is most likely to occur. It is unclear
whether there is any benefit to using priorities for other egress ports
within the switching fabric. Congestion is less likely to occur at these
ports (see {{secBuffers}} for discussion) and the priorities computed by Homa may
not make much sense within the switching fabric (the priorities for each
receiver are computed independently, and the packets at an egress port
within the fabric could represent a variety of receivers, so it doesn't
make sense to compare their priorities).

# Retransmission and Timeouts {#secRetrans}

Homa uses unreliable datagram protocols for packet delivery, so it
must be prepared to retransmit lost packets. In Homa, retransmission of
message data is requested explicitly by the receiver of the message,
using `RESEND` packets as described in {{secResendPkt}}.

## When to issue RESENDs

`RESEND` packets are triggered by lack of progress in a message.
Specifically, if a period of time elapses without the arrival
of an expected data packet, then the receiver for the message
issues a `RESEND`
packet for the missing data. Ultimate responsibility for `RESEND`s
lies with the client: if it has not received the entire response
message within an expected time then it MUST issue `RESEND` request(s)
for the missing part(s) of the response. The client MUST issue
`RESEND`s for the response even if the request message has not been
fully transmitted, for reasons given in the next paragraph.

Servers MUST issues `RESEND`s for missing parts of the request message;
these MAY
be triggered in either of two ways. First, the server MAY set its own timers
to track progress on request messages and then issue `RESEND`s if
packets do not arrive in a timely fashion. However, these timers are
not sufficient because all of the packets of the request message may be
lost. If this happens the server will have no knowledge of the RPC and
cannot issue `RESEND`s. However, the client will eventually
send a `RESEND` for the response. If a `RESEND` arrives at a server
for an unknown RPC, then the server MUST issue a `RESEND` for the initial
part of the request message. A server MAY choose not to set its own
timers and to rely entirely on `RESEND` requests sent by clients.

Choosing the *resend interval* (how long to wait for expected data before
issuing `RESEND`s) involves a tradeoff among several considerations:

* If a packet has been lost, it is desirable to issue the `RESEND` as
  quickly as possible; long resend intervals introduce unnecessary
  delays.

* Short resend intervals create unnecessary overheads if packets are
  delayed but not actually lost. For example, on Linux
  servers as of December 2025, packets occasionally experience
  software processing delays of 5ms or more on the receiving host.

* `RESEND`s will occur when the service time for an RPC is longer than
  the resend interval. These `RESEND`s are unnecessary and waste resources,
  so the resend interval should be large enough to cover most service
  times.

*Mention the resend interval in the Linux kernel implementation?*

## Avoiding unnecessary RESENDs

There are some situations where `DATA` packets for a message do not arrive,
but the receiver can determine from its own state that it should not expect
those packets to arrive until it takes additional steps. In such situations
endpoints SHOULD NOT send extraneous `RESEND`s. Here are a few examples:

* If all granted bytes have been received, then a receiver should not issue
  `RESEND`s for bytes that have not yet been granted.

* If a client has not yet transmitted all of the granted (or unscheduled)
  bytes for a request message, it should not issue a `RESEND` for the response.

## Responding to RESENDs

When an endpoint receives a `RESEND` packet it MUST respond in order to prevent
timeouts at the receiver. It MAY respond in either of three ways:

* The endpoint receiving the `RESEND` MAY retransmit the range of bytes
  requested in the `RESEND` packet (it MUST set the `Retrans` flag in each
  retransmitted DATA packet).

* The endpoint receiving the `RESEND` MAY respond with a `RESEND`. This happens
  if the receiver of the `RESEND` is the server for the RPC, but it has
  received no DATA packets for the request.

* The endpoint receiving the `RESEND` MAY respond with a BUSY packet. This
  indicates that the recipient of a `RESEND` is alive and aware of the message but is not
  yet prepared to transmit the requested data. This can happen if a server
  receives a `RESEND` for an RPC's response at a time when it has received
  the entire request but the RPC is still being serviced so the response
  message is not yet ready. This can also happen if the endpoint receiving
  the `RESEND` has chosen not to transmit the "missing" data (e.g., it is
  using all of its uplink bandwidth for higher priority transmissions).

## Timeouts

If an endpoint issues multiple `RESEND` packets for an RPC and receives no
response from the peer endpoint, the peer is considered to have timed out.
When this happens, all RPCs involving that endpoint SHOULD be aborted.

An endpoint SHOULD NOT delete per-peer state for a timed-out endpoint,
such as unscheduled priority cutoffs. This is because the peer might
not have actually crashed. It is possible that the timeout occured
because of a disruption in communication, but the peer is still alive
and will eventually resume communication.

An endpoint SHOULD NOT timeout a peer until multiple `RESEND` packets
have been issued with no response. This is because any given `RESEND`
packet could potentially be lost. Timeouts are expected to be infrequent
and the consequences of a timeout are relatively severe, so it is
better to wait long enough to be quite certain that the peer has
crashed or is unreachable.

# At-Most-Once Semantics {#secAcks}

Homa endpoints MUST ensure that an RPC presented to Homa by a client
is executed on the server exactly once as long as neither the client
nor the server crashes and they can communicate. If there is a crash of
either client or server during an RPC, or if there is an extended
disruption in communication, then the RPC MAY be executed on the
server either once or not at all. RPCs MUST NOT ever be executed more
than once.

Ensuring at-most-once semantics requires careful management of RPC
state on servers. The server creates internal state for an RPC
when it receives the first `DATA` packet for that RPC. Under normal
conditions the state will be retained until the RPC has been executed
by the application and the result has been returned to the client.

Up until the request message is passed to the server application for
execution, the server MAY delete its state for the RPC: this is not
generally advisable for performance reasons, but it is safe from
the standpoint of
at-most-once semantics. Once the request message has been passed to
the server application, the server endpoint MUST retain its state
for the RPC until the client has received the response message or
the server has reason to believe the client has crashed.
If a server were to delete its state before one of these events
occurs, then a `RESEND` from the client could cause the creation
of a new RPC on the server, resulting in a second execution.

Homa includes an acknowledgment mechanism that clients use to notify
servers that they have received the full response for an RPC; this
indicates to the server that it can safely delete its state for the
RPC. Acknowledgments MAY be made in either of two different ways:

* The acknowledgment for an RPC MAY be piggybacked on a future `DATA`
  packet sent by the client. Each `DATA` packet includes space in its header
  to acknowledge one RPC.

* A client MAY send an explicit `ACK` packet, which may contain multiple
  acknowledgments.  This form may be useful if a client has RPCs to
  acknowledge but no new RPCs to use for piggybacking acknowledgments.
  `ACK`s are also sent in response to `NEED_ACK` packets, as discussed
  below.

Acknowledgments are not reliable. Both `DATA` and `ACK` packets may be lost,
and there is no way for a client to know whether an acknowledgment has been
received by the server. Although clients SHOULD attempt to acknowledge
each completed RPC, they MAY delete information about a pending
acknowledgment once it has been included in a `DATA` or `ACK` packet.

If a server fails to receive an acknowledgment within a reasonable
time after sending the last `DATA` packet for a response message,
then it MUST request an acknowledgment for the RPC using a `NEED_ACK`
packet. When a client receives a `NEED_ACK` packet, it MUST return
an `ACK` packet unless it can determine that it has not received
the RPC's response. A client must return an `ACK` if it has no
state for the RPC (this is likely to be the case, since the client
can delete its state for an RPC once it has received the response).

If a client receives a `NEED_ACK` packet for an RPC with an incomplete
response, it MUST NOT return an `ACK` packet. However, it
MAY issue `RESEND` requests for missing packets at this time.

`NEED_ACK` packets are not reliable, so servers MUST continue to issue
`NEED_ACK` requests for an RPC until an acknowledgment has been received.
 If an extended period of time elapses with no communication of any
 sort from the peer endpoint for the RPC, then the server MAY assume
 that the client has crashed and reclaim its state for the RPC.

An extended disruption of communication can cause the server to assume
a client crash and delete its state for the RPC. The timeout period on
the server MUST be long enough so that even if the client has not
actually crashed it will have timed out the RPC on its end and aborted
it.

## Discussion

This mechanism is not quite adequate to prevent multiple executions. If
a request packet is delayed in the network long enough for the server to
receive its acknowledgment and delete its state, and if the packet
contains an entire request, it could trigger a second execution on the
server. To prevent this, servers will need to maintain additional state
to detect long-delayed packets.
This might include an rpcid for each client, such that all RPCs with
rpcid's less than or equal to this have been processed.

It is questionable whether at-most-once semantics are worth the complexity
they add to the protocol. Applications generally expect it, so not
attempting to provide it could discourage Homa adoption.
However, applications are likely to retry operations after
server crashes, which can lead to multiple executions. Thus, the
only truly safe approach is for duplicate executions to be detected and
discarded at application level. This isn't a problem that can be solved
entirely by network transport.

# Pacing {#secPacer}

Homa endpoints MUST implement an SRPT policy for packet transmission,
where packets from short messages are given priority for transmission
over those from long messages. However, few if any NICs  support a notion
of transmit priority: packets will be transmitted in the order in which
they were enqueued at the NIC. If a long queue of transmit packets
builds up in the NIC, then a new packet for a short
message will suffer head-of-line blocking in the NIC transmit queue.
Homa endpoints MUST attempt to reduce head-of-line blocking delays in
the NIC for short messages.

To prevent head-of-line blocking delays in NICs that do not support
priorities, Homa endpoints MUST limit the buildup of transmit queues
in the NIC. One way to do this is with a *pacer*, which throttles the
rate at which packets are enqueued in the NIC.  As a result, if there
is a large accumulation of outbound packets it occurs in the internal
queue(s) of the
Homa endpoint, not in the NIC.  The Homa endpoint can manage its
internal queues according to SRPT so that short messages are not
delayed by long ones.

Here are some considerations for the design of the pacing mechanism:

* The timing of a software pacing mechanism is not perfectly predictable
  (e.g., the pacer could be delayed by interrupts)
  so the pacer must build up a small queue in the NIC in
  order to keep the uplink fully utilized if the pacer is momentarily
  non-responsive. In the Linux kernel implementation, 5 μs worth of data seems
  to be adequate.

* The pacing mechanism must include all outbound network traffic,
  including packets from TCP and other non-Homa protocols. Otherwise
  non-Homa traffic can generate long NIC queues, which will degrade
  Homa performance.

* The pacer should limit output to just slightly less than the network
  bandiwidth in order to be safe. If it errs and generates output at
  a rate even slightly higher than the network bandwidth, long queues
  will build up in the NIC during bursts of high load.

When implementing an SRPT policy for packet transmission, Homa
endpoints MAY choose to reserve a small amount of outbound
bandwidth for the oldest message in order to prevent starvation.
The motivation for this is similar to the FIFO granting mechanism
described in {{secGrants}}.

# Managing Buffer Occupancy in Switches {#secBuffers}

Homa's performance will degrade badly if packets are dropped frequently
because of buffer overflows in the network switches (occasional packet
drops are not problematic). Homa does not depend on packet drops for a
congestion signal, so in principle there should be no packet drops.
However, modern switches have limited buffer space and the amount of
switch buffer memory is not increasing as quickly as network bandwidth.
This increases the likelihood that switch buffers will overflow.

## Sources of buffer buildup

The most common location for buffer buildup is at the edge downlinks from
TORs to hosts. Queuing is caused by incast,
where multiple senders transmit simltaneously to the same receiver.
Assuming all links have the same bandwidth, there is no way for the
receiver's downlink to transmit packets as fast as they arrive
at the TOR.

Homa gives receivers considerable control over their incoming
traffic, and thus over buffer buildup. However, queuing at TOR
downlinks can still happen in 2 ways:

* Unscheduled packets. Senders can transmit the initial bytes of messages
  without receiving permission in advance from receivers. This feature
  provides a significant latency benefit, but it carries the risk of
  buffer buildup. There is no limit to how many senders
  can transmit unscheduled packets to the same receiver at once.

* Granted packets. Receivers intentionally issue grants to multiple
  incoming messages at once (overcommitment); this will result in
  buffer buildup in the switch. The buffer buildup from granted packets
  is limited by the degree of overcommitment: as discussed previously
  in {{secGrants}}, the
  worst-case packet queuing in the switch from grants will be equal to the
  receiver's total incoming data, minus one BDP.

Both forms of queuing can happen simultaneously.

Buffer buildup can also occur within the switching fabric, for example
if multiple long messages are routed across the same internal link in
the fabric.

## Configuring the network

Network switches SHOULD configured in 2 ways to reduce the likelihood of
buffer overflows for Homa:

* Buffer space within a switch SHOULD be shared dynamically across
  egress ports as much as possible, rather than statically allocating
  space to each port. This is particularly important for the TOR
  downlinks: when incast occurs at one port, there will be other
  ports that are underutilized. It is unlikely that there will be large
  queues on many egress ports simultaneously.

* Packet spraying SHOULD be used for Homa packets within the switching
  fabric (i.e.  different packets within a message may take different
  paths through the fabric in order to balance loading within the fabric).
  In contrast, TCP requires flow-consistent routing: packet reorderings
  cause problems for TCP, so all of the packets within a TCP flow must
  follow the same path through the fabric to prevent reorderings.
  With flow-consistent routing, queues can build up in the fabric if
  two flows happen to share an internal link within the fabric; this
  can occur even if the fabric overall is underutilized. With
  packet spraying, queues are unlikely to form in the fabric unless
  the entire fabric is running at near-capacity (and modern datacenters
  are generally configured with excess fabric capacity).

## Dealing with inadequate buffer space

Depending on the workload, the network speed, and the available switch
buffer space, it is possible that packet drops may occur for Homa
at an unacceptably high level. If this happens, Homa can be modified
in two ways to reduce its buffer utilization.

* Reduce the amount of unscheduled data allowed for each message.
  Ideally, the amount of unscheduled data should equal the BDP:
  this allows messages to be transmitted at full network bandwidth
  when the network is underloaded. Reducing the amount of unscheduled data
  will introduce a smalll delay for messages that require grants
  (e.g., if the unscheduled data limit is reduced to 0.6 BDP, then
  messages needing grants will incur an extra delay of 0.4 RTT)
  but it will also reduce buffer usage during incast of unscheduled
  packets.

* Use grants to limit the total amount of incoming data. To do this,
  Homa endpoints SHOULD keep track of their total incoming data,
  including both unscheduled and scheduled data.
  An adjustable limit SHOULD be supported, such that grants will not
  be issued when total incoming data exceeds the limit. As the limit
  is reduced, Homa endpoints SHOULD either reduce the degree of
  overcommitment or reduce the amount of incoming for each message
  below one BDP.  Each of these reductions will have some impact
  on throughput, but this impact is likely to be less damaging
  than the impact of frequent packet drops.

*Discuss in detail the approach used in Linux?*

# Acknowledgments

TBD

# Security Considerations

This area is currently almost completely unaddressed in Homa. I
need help identifying potential threats to consider and/or how
to think about potential security issues.

# IANA Considerations

IANA has assigned IP protocol number 146 for Homa.

# Questions and Unresolved Issues

This section contains questions about how to organize this document,
plus issues that are not yet resolved in this spec (and in the current
Linux implementation of Homa) or that may be bugs.

* How to decide whether to use MUST vs. SHOULD? E.g., if something
  only affects performance but not correctness, is that a SHOULD?

* To what degree should this document discusses policy choices, vs. just
  the mechanisms? In some cases, such as policies for issuing grants,
  it's not a problem if different endpoints use different policies.
  To what degree should that be reflected here?

* How much should this document reflect current hardware and software
  characteristics?

* Should this document describe details of the Linux implementation?
  This information might be useful to people writing new implementations.

* Check the second and third scenarios for `BUSY` packets in the Linux
  code; do these still make sense?

* Could `BUSY` packets be eliminated and replaced with empty `DATA`
  packets?

* Ideally, packet spraying should be used in the switching fabric. However,
  Homa should also be able to spray packets by varying one of the port fields.

* Specify constants, such as largest message length and number of priorities?

* Change so that messages are either entirely unscheduled or entirely
  scheduled?

* How to determine the limit for unscheduled bytes? Include in CUTOFFS packets?

* Change to drive retransmission entirely from the client?

* Discuss TCP hijacking

--- back

# Acknowledgments
{:numbered="false"}

TODO acknowledge.
