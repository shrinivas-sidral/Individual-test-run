#!/bin/bash

# change the project
oc project openshift-storage

# ceph crash archive
echo "#######  ceph crash ls  #######";echo; oc -n openshift-storage rsh `oc get pods -n openshift-storage | grep rook-ceph-tools |  awk '{print $1}'` ceph crash ls; echo
echo "#######  ceph crash archive  #######";echo; oc -n openshift-storage rsh `oc get pods -n openshift-storage | grep rook-ceph-tools |  awk '{print $1}'` ceph crash archive-all; echo
