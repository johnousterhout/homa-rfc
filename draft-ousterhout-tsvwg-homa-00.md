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

informative:
  ReplaceTCP:
    title: "It's Time to Replace TCP in the Datacenter"
    author:
      - name: John Ousterhout
        ins: J. Ousterhout
        org: Stanford University
    date: January, 2023
    target:
      https://arxiv.org/abs/2210.00714

  Homa:
    title: "Homa: A Receiver-Driven Low-Latency Transport Protocol Using Network Priorities"
    author:
      - name: Benham Montazeri
        ins: B. Montazeri
        org: Stanford University
      - name: Yilong Li
        ins: Y. Li
        org: Stanford University
      - name: Mohammad Alizadeh
        ins: M. Alizadeh
        org: MIT
      - name: John Ousterhout
        ins: J. Ousterhout
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

Homa is a clean-slate redesign of network transport for datacenter
applications (it is not suitable for wide area communication).
As a result, Homa provides significantly better performance than
TCP. Homa provides lower latency than TCP across a wide range of message
lengths and workloads, but its greatest benefits are for short
messages in mixed workloads running at high network utilization:
lab experiments show 10-100x reduction in tail latency under
these conditions [HomaLinux].

See [Homa] for more on the rationale for Homa, the original design
of Homa (which differs somewhat from the protocol described here) and
early performance measurements. [HomaLinux] describes the first
implementation of Homa in Linux, with additional performance
measurements.

# Conventions and Definitions

{::boilerplate bcp14-tagged}

Commonly used terms in this document are described below.

**Homa:**
: The transport protocol described by this document. Homa is a name,
  not an acronym.

**Remote Procedure Call (RPC):**
: The primary abstraction implemented by Homa, consisting of a request
message sent from client to server, followed by a response message
returned from the server back to the client.

**Endpoint:**
: An entity that implements the Homa protocol, typically associated with
a single network link on a given machine. Endpoints can support both
clients and servers.

**Client:**
: An entity that initiates a Homa RPC: it sends a request message and
receives the response. This term may refer to either the
application that initiates the RPC or the endpoint that implements it.

**Server:**
: An entity that receives a Homa request and sends the corresponding
response. This term may refer to either an application program or the
the point that implements it.

**Message:**
: The unit of communication that Homa provides to applications.
A message consists of a fixed-length array of bytes ranging in length from a
single byte up to a system-defined upper limit. There are two kinds
of messages in Homa: requests and responses.

**Packet:**
: The unit of transmission between Homa endpoints. Each packet has one
of several types and consists of a type-specific header followed
optionally by part or all of the data for a single message.

**Rpcid:**
: An integer that uniquely identifies a given RPC among all of the
RPCs initiated from the same endpoint. The pair <endpoint address, rpcid>
provides a system-wide unique identifier for a Homa RPC. Rpcids are
always even and increase sequentially in order of creation on the
client.

# Description

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
~~~

# Security Considerations

TODO Security


# IANA Considerations

This document has no IANA actions.


--- back

# Acknowledgments
{:numbered="false"}

TODO acknowledge.
