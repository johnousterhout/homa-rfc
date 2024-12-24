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

* Homa prioritizes shorter messages over longer ones. It does this in two ways:

  * Homa takes advantage of the priority queues in datacenter switches,
    arranging for shorter messages to use higher-priority queues.

  * When multiple messages are inbound to a single receiver, the
    receiver uses grants to prioritize shorter messages.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

Commonly used terms in this document are described below.

**Client:**
: An entity that initiates a Homa RPC: it sends a request message and
receives the response. This term may refer to either the
application that initiates the RPC or the endpoint that implements it.

**Endpoint:**
: An entity that implements the Homa protocol, typically associated with
a single network link on a given machine. Endpoints can support both
clients and servers.

**Grant:**
: A token issued by the receiver for a message, which entitles the
  message sender to transmit all of the bytes of the message up to a
  given offset. The grant also specifies the priority to use in
  the message's data packets.

**Homa:**
: The transport protocol described by this document. Homa is a name,
  not an acronym.

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
the point that implements it.

**TCP Segmentation Offload (TSO):**
: A hardware feature implemented by most NICs, which allows host
software to process outgoing network data in units larger than
the network MTU. With TSO, the host generates "TSO frames",
which look like packets that exceed the MTU. The NIC divides
each TSO frame into multiple smaller packets ("segments") for
transmission. In this document the term "packet" always refers
to the entities transmitted on the wire, not TSO frames.

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
in order to ensure correct TSO behavior; never used by receivers.

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

* How to determine the limit for unscheduled bytes?

--- back

# Acknowledgments
{:numbered="false"}

TODO acknowledge.
