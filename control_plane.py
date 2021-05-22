# Name: Junyong Zhao
# PennKey: junyong

import argparse
import json
import os
import sys
import threading
from time import sleep

sys.path.append("utils")
import bmv2
import helper
from convert import *


# User control plane code goes here
def RunControlPlane(sw, id_num, p4info_helper):
    # TODO: finish this function to properly configure the switch and to learn
    #       new MAC addresses as they arrive.  A correct implementation will not
    #       use id_num.

    # add multicast ports for every switch
    mac_adds = set()
    mcasts_entry = p4info_helper.buildMulticastEntry(1, [2, 3])
    sw.AddMulticastGroup(mcasts_entry)

    mcasts_entry = p4info_helper.buildMulticastEntry(2, [1, 3])
    sw.AddMulticastGroup(mcasts_entry)

    mcasts_entry = p4info_helper.buildMulticastEntry(3, [1, 2])
    sw.AddMulticastGroup(mcasts_entry)

    digest_request = p4info_helper.buildDigestConfig("ethlearn_digest_t")

    # listen to digest reporting
    while 1:
        response = sw.GetDigest(digest_request)
        mac = decodeMac(response.digest.data[0].struct.members[0].bitstring)
        port = decodeNum(response.digest.data[0].struct.members[1].bitstring)

        # build for tiLearnMAC table
        tilearn_entry = p4info_helper.buildTableEntry(
            table_name="cis553Ingress.tiLearnMAC",
            match_fields={"hdr.ethernet.srcAddr": mac},
            action_name="cis553Ingress.NoAct",
            action_params={})

        # build for tiForward table
        tifwd_entry = p4info_helper.buildTableEntry(
            table_name="cis553Ingress.tiForward",
            match_fields={"hdr.ethernet.dstAddr": mac},
            action_name="cis553Ingress.aiForward",
            action_params={"egress_port": port})

        # build for tiFilter table
        tiflt_entry = p4info_helper.buildTableEntry(
            table_name="cis553Ingress.tiFilter",
            match_fields={"hdr.ethernet.dstAddr": mac,
                          "standard_metadata.ingress_port": port},
            action_name="cis553Ingress.drop",
            action_params={})

        # update tables
        if mac not in mac_adds:
            sw.WriteTableEntry(tilearn_entry)
            sw.WriteTableEntry(tifwd_entry)
            sw.WriteTableEntry(tiflt_entry)
        else:
            sw.UpdateTableEntry(tilearn_entry)
            sw.UpdateTableEntry(tifwd_entry)
            sw.UpdateTableEntry(tiflt_entry)
            mac_adds.add(mac)
    sw.shutdown()


# Starts a control plane for each switch. Hardcoded for our Mininet topology.
def ConfigureNetwork(p4info_file="build/data_plane.p4info",
                     bmv2_json="build/data_plane.json"):
    p4info_helper = helper.P4InfoHelper(p4info_file)

    threads = []

    print "Connecting to P4Runtime server on s1..."
    sw1 = bmv2.Bmv2SwitchConnection('s1', "127.0.0.1:50051", 0)
    sw1.MasterArbitrationUpdate()
    sw1.SetForwardingPipelineConfig(p4info=p4info_helper.p4info,
                                    bmv2_json_file_path=bmv2_json)
    t = threading.Thread(target=RunControlPlane, args=(sw1, 1, p4info_helper))
    t.start()
    threads.append(t)

    print "Connecting to P4Runtime server on s2..."
    sw2 = bmv2.Bmv2SwitchConnection('s2', "127.0.0.1:50052", 1)
    sw2.MasterArbitrationUpdate()
    sw2.SetForwardingPipelineConfig(p4info=p4info_helper.p4info,
                                    bmv2_json_file_path=bmv2_json)
    t = threading.Thread(target=RunControlPlane, args=(sw2, 2, p4info_helper))
    t.start()
    threads.append(t)

    print "Connecting to P4Runtime server on s3..."
    sw3 = bmv2.Bmv2SwitchConnection('s3', "127.0.0.1:50053", 2)
    sw3.MasterArbitrationUpdate()
    sw3.SetForwardingPipelineConfig(p4info=p4info_helper.p4info,
                                    bmv2_json_file_path=bmv2_json)
    t = threading.Thread(target=RunControlPlane, args=(sw3, 3, p4info_helper))
    t.start()
    threads.append(t)

    for t in threads:
        t.join()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='CIS553 P4Runtime Controller')

    parser.add_argument("-b", '--bmv2-json',
                        help="path to BMv2 switch description (json)",
                        type=str, action="store",
                        default="build/data_plane.json")
    parser.add_argument("-c", '--p4info-file',
                        help="path to P4Runtime protobuf description (text)",
                        type=str, action="store",
                        default="build/data_plane.p4info")

    args = parser.parse_args()

    if not os.path.exists(args.p4info_file):
        parser.error("File %s does not exist!" % args.p4info_file)
    if not os.path.exists(args.bmv2_json):
        parser.error("File %s does not exist!" % args.bmv2_json)

    ConfigureNetwork(args.p4info_file, args.bmv2_json)
