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

TODO Abstract


--- middle

# Introduction

Homa is a network transport protocol designed specifically for use in
datacenter environments where large numbers of machines can
communicate with each other with microsecond-scale latency.
Homa is different from TCP in several ways: it is
Homa is a message-based protocol that implements remote procedure
calls (RPCs). Readers can learn more from.

## Background

In spite of its long and successful history, TCP is a poor transport
protocol for modern datacenters. Every significant element
of TCP, from its stream orientation to its expectation
of in-order packet delivery, is wrong for the datacenter [ReplaceTCP].
As a result, applications using TCP cannot achieve the full performance
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
  transmitted unilaterally by the sender, but the scheduled receiver
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
application that initiates the RPC or to the endpoint that implements it.

**Endpoint:**
: An entity that implements the Homa protocol, typically associated with
a single network link on a given machine. Endpoints can acts both
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
  transmitted but have not yet been received. Data is authorized it is
  within the unscheduled region of a message or if the receiver has
  transmitted a `GRANT` packet for it. Data is considered "incoming"
  even if the sender has not yet received the grant or the data has
  not yet been transmitted.

**Message:**
: The unit of communication that Homa provides to applications.
A message consists of a fixed-length array of bytes ranging in length from a
single byte up to a system-defined upper limit. There are two kinds
of messages in Homa: requests and responses.

**Packet:**
: The unit of transmission between Homa endpoints. Each packet has one
of several types and consists of a type-specific header followed
optionally by part or all of the data for a single message.

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

**Common Header:**
: The initial bytes of each packet, which have the same format in all
packets regardless of type.

**Maximum Transmission Unit (MTU):**
: The maximum allowable size for a network packet, including all headers.

**Priority:**
: A value in the range \[0-7\], which is included in transmitted packets
  and used by network switches to select a priority queue for the packet.
  Switches should be configured to transmit higher-priority packets in
  preference to lower-priority ones.

**Scheduled Data:**
: The remainder of a message after the unscheduled data. Transmission
  of scheduled data is controlled by the receiver, which issues
  grant packets.

**Server:**
: An entity that receives a Homa request and sends the corresponding
response. This term may refer to either an application program or the
endpoint that implements it.

**SRPT (Shortest Remaining Pressing Time):**
: Homa tries to prioritize messages that have the fewest remaining
  bytes to transmit, but on the sender side and the receiver side.

**TCP Segmentation Offload (TSO):**
: A hardware feature implemented by most NICs, which allows host
software to process outgoing network data in units larger than
the network MTU. With TSO, the host generates "TSO frames",
which look like packets that exceed the MTU. The NIC divides
each TSO frame into multiple smaller packets ("segments") for
transmission. In this document the term "packet" always refers
to the entities transmitted on the wire, not TSO frames.

**Top of Rack Switch (TOR):**
: The network switches at the edges of the datacenter switching
  fabric. Individual hosts connect to TORs.

**Unscheduled Data:**
: The initial portion of a message, which may be transmitted
  unilaterally by the sending without waiting for permission
  from the receiver.

# Packets

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
the machine that redeives the packet.

**Offset:**
: Used only for DATA packets, and only under conditions described
below; contains the offset within the message of the first byte
of data in the packet.

**Type:**
: Type of this packet. Must have one of the following values:

~~~
     DATA      16
     GRANT     17
     RESEND    18
     UNKNOWN   19
     BUSY      20
     CUTOFFS   21
     NEED_ACK  23
     ACK       24
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

## DATA packets

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
specifies an RPC. If the `S` bit is set in the common header then this
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
See Section XXX below for details on.

**Ack Server Port:**
: The port number (on the server) to which `Ack Rpcid` was sent.

**Cutoff Version:**
: The current version number for the priority cutoffs currently used
on the sender for this receiver. See Section XXX below for details.

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

## GRANT packets

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

## RESEND packets

A Homa endpoint sends `RESEND` packets when message data that it is expecting
to receive is overdue. The structure of a resend packet is specified by
{{resendPkt}} below:

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

## UNKNOWN packets

A Homa endpoint sends a packet with type `UNKNOWN` when it receives a
`RESEND` packet with an Rpcid that is uknonwn to it (i.e. the endpoint
has no outbound message for that Rpcid). An `UNKNOWN` packet consists of
a common header with no additional informatioin.

## BUSY packets

Packets with type `BUSY` are sent by servers when they receive a
`RESEND` packet for the response message but the response message is
not yet ready, either because the request has not been fully received
or because the application has not yet generated a response.
`BUSY` packets are not sent by clients.
A `BUSY` packet consists entirely of the common header.

## CUTOFFS packets

Packets with type `CUTOFFS` instruct the recipient how to
assign priorities for unscheduled packets in the future. The structure of
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
MUST bethe largest `i` such that `Cutoffs[i]` is greater than or
equal to the length
of the packet's message. Entry 0 in `Cutoffs` must be greater than or
equal to the largest allowable message length.

**Cutoff Version:**
: Identfiies this particular choice of cutoffs; the `CUTOFFS` recipient
MUST be include this value as the `Cutoff Version` in all
future `DATA` packets sent to the `CUTOFFS` sender (allows the sender to
detect when cutoffs have become stale and need to be refreshed).

## NEED_ACK packets

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

## ACK packets

An `ACK` packet is sent from a client to a server.  It acknowledges that
the server can safely reclaim its state for one or more RPCs.
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
: The server port number to which `Ack Rpcid` was targeted.

# Policy Considerations for Grants

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
overheads. For example, delay can be measured on the sender as the time
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
considerations probably make this amount impractical.

## SRPT and Overcommitment

Grants play an important role in implementing SRPT. If a receiver has
multiple inbound messages, it SHOULD use grants to prioritize messages
with fewer remaining bytes to transmit.

The simplest approach would be to issue grants only to the highest priority
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
only grants to one message and that message's sender choose not to
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
discussed below.

The second problem with overcommitment is that it increases buffer
occupancy in the network switch. If a receiver grants to multiple inbound
messages and all of their senders transmit, the aggregate bandwidth of
transmission will exceed the bandwidth of the receiver's downlink, so
packets will be buffered at the egress port in the TOR. The amount of
buffer space occupied will equal the total incoming across all of the
receiver's inbound messages, less one BDP. Thus, the
more messages a receiver grants to, the more buffer space will be
consumed in the TOR (assuming total incoming increases with the degree
of overcommitment). Buffer management is discussed in more detail below.

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
hsa been measured at 30-40 Gbps on some machines; this is inadequate
to support a 100 Gbps link). When this occurs, it may make sense to
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
5% seems adequate to eliminate starvation.

# Priorities and Cutoffs

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
for all subsequent packets in the associated message. The receiver thus
has direct control over the priority for each scheduled packet. When a
receiver grants to multiple inbound messages at once, it SHOULD assign
a different priority for each message (highest priority for the message
with the least remaining bytes to transmit). This ensures that when
multiple senders transmit simultaneously and the receiver's TOR link
is overcommitted, packets from the highest priority message will be
transmitted and packets for other messages will be buffered in the TOR.
If the sender chooses not to transmit the highest priority message,
then packets from other messages will get through to the receiver.
The use of priorities allows Homa to achieve "perfect" SRPT even when
overcommitting its TOR link.

## Unscheduled packets

For unscheduled packets the receiver must assign packet priorities in
advance. It does this by analyzing redent incoming traffic and
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
data packet is received, the receiver SHOULD check the Cutoff
Version in the packet; if it is out of date, the receiver SHOULD
send a new `CUTOFFS` packet to update the sender.

Homa endpoints SHOULD assign unscheduled priorities so that each
priority level is used for about the same number of incoming bytes.
First, an endpoint can use recent traffic statistics to compute the
total fraction of incoming bytes that are unscheduled. The available
priority levels SHOULD be divided between unscheduled packets and
schedule packets using this fraction; e.g., if 75% of incoming bytes
are unscheduled, then 75% of available priority levels SHOULD be used
for unscheduled packets and 25% of available priority levels SHOULD be
used for scheduled packets. The highest priority levels MUST be
assigned to unscheduled packets. At least one priority level MUST be
available for each of unscheduled and scheduled packets, but the
lowest unscheduled priority level may also be used as the highest
scheduled priority level.

Once the number of unscheduled priority levels is known, the cutoffs
between unscheduled priorities SHOULD be chosen so that each priority
level is used for the same amount of traffic (based on recent traffic
patterns). Higher priority levels go to shorter messages.

## How many priority levels?

Measurements suggest that 4 priority levels is enough to produce
good performance for Homa and additional priority levels beyond 4
provide little benefit [HomaLinux]. Homa can operate with a single
priority level and still provide considerable latency improvements
over TCP, though a second priority level provides significant latency
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
ports (see below for discussion) and the priorities computed by Homa may
not make much sense within the switching fabric (the priorities for each
receiver are computed independently, and the packets at an egress port
within the fabric could represent a variety of receivers, so it doesn't
make sense to compare their priorities).

# Managing Buffer Occupancy

TBD

* Messages allow predicting the future

* Packet spraying, using client-side port field

# Retransmission and Timeouts

TBD

# Pacing

FIFO?

# Acknowledgments

TBD

# Security Considerations

This area is currently almost completely unaddressed in Homa. I
need help identifying potential threats to consider and/or how
to think about potential security issues.

# IANA Considerations

This document has no IANA actions.

# Unresolved Issues

This section lists issues that are not adequately resolved in this
spec (and in the current Linux implementation of Homa), or that may
be bugs.

* Check the second and third scenarios for `BUSY` packets in the Linux
  code; do these still make sense?

* Could `BUSY` packets be eliminated and replaced with empty `DATA`
  packets?

* Ideally, packet priorities will only be used at downlinks. Within
  the swiching fabric, packets should be processed in FIFO order.

* Ideally, packet spraying should be used in the switching fabric. However,
  Homa should also be able to spray packets by varying one of the port fields.

* Specify constants, such as largest message length and number of priorities.

* Change so that messages are either entirely unscheduled or entirely
  scheduled?

* How to determine the limit for unscheduled bytes? Include in CUTOFFS packets?

* Change to drive retransmission entirely from the client?

* How much should this document reflect current hardware and software
  characteristics?

--- back

# Acknowledgments
{:numbered="false"}

TODO acknowledge.
