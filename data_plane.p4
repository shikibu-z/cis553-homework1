// Name: Junyong Zhao
// PennKey: junyong

/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>


/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

struct headers_t {
    ethernet_t  ethernet;
}


struct local_variables_t {
}


struct ethlearn_digest_t {
    bit<48> srcAddr;
    bit<9>  srcPort;
}


/*************************************************************************
***********************  P A R S E   P A C K E T *************************
*************************************************************************/

parser cis553Parser(packet_in packet,
                    out headers_t hdr,
                    inout local_variables_t metadata,
                    inout standard_metadata_t standard_metadata) {
    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition accept;
    }
}


/*************************************************************************
***********************  I N G R E S S  **********************************
*************************************************************************/

control cis553Ingress(inout headers_t hdr,
                      inout local_variables_t metadata,
                      inout standard_metadata_t standard_metadata) {
    // Example action that sends a digest of the current packet to the control
    // plane
    action aiSendDigest() {
        ethlearn_digest_t mac_learn_digest = {hdr.ethernet.srcAddr,
                                              standard_metadata.ingress_port};
        digest(0, mac_learn_digest);
    }

    // Example action that multicasts the current packet to a preconfigured
    // group
    action aiMulticast() {
        bit<16> multicast_group = (bit<16>) standard_metadata.ingress_port;
        standard_metadata.mcast_grp = multicast_group;
    }

    // Do noting
    action NoAct() {
        NoAction();
    }

    table tiLearnMAC {
        key = {
            // DONE
            hdr.ethernet.srcAddr : exact;
        }
        actions = {
            // DONE
            NoAct;
            aiSendDigest;
        }
        default_action = aiSendDigest();
    }

    // An aiForward action to use
    action aiForward(bit<9> egress_port) {
        standard_metadata.egress_spec = egress_port;
    }

    table tiForward {
        key = {
            // DONE
            hdr.ethernet.dstAddr : exact;
        }
        actions = {
            // DONE
            aiForward;
            aiMulticast;
        }
        default_action = aiMulticast();
    }

    action drop() {
        mark_to_drop(standard_metadata);
    }

    table tiFilter {
        key = {
            // TODO
            hdr.ethernet.dstAddr : exact;
            standard_metadata.ingress_port : exact;
        }
        actions = {
            // TODO
            drop;
            NoAct;
        }
        default_action = NoAct();
    }

    apply {
        tiLearnMAC.apply();
        tiForward.apply();
        tiFilter.apply();
    }
}


/*************************************************************************
***********************  E G R E S S  ************************************
*************************************************************************/

control cis553Egress(inout headers_t hdr,
                     inout local_variables_t metadata,
                     inout standard_metadata_t standard_metadata) {
    apply { }
}


/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control cis553VerifyChecksum(inout headers_t hdr,
                             inout local_variables_t metadata) {
     apply { }
}


/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   ***************
*************************************************************************/

control cis553ComputeChecksum(inout headers_t hdr,
                              inout local_variables_t metadata) {
    // The switch handles the Ethernet checksum.
    // We don't need to deal with this.
    apply { }
}


/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   ********************
*************************************************************************/

control cis553Deparser(packet_out packet, in headers_t hdr) {
    apply {
        packet.emit(hdr.ethernet);
    }
}


/*************************************************************************
***********************  S W I T C H  ************************************
*************************************************************************/

V1Switch(cis553Parser(),
         cis553VerifyChecksum(),
         cis553Ingress(),
         cis553Egress(),
         cis553ComputeChecksum(),
         cis553Deparser()) main;
