#!/bin/bash

VBoxManage storageattach "BlueCentOS" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium none
