#!/bin/bash

openFPGALoader -b tangnano9k -f impl/pnr/tang-nano-9k--step-10.fs
#openFPGALoader -b tangnano9k impl/pnr/tang-nano-9k--step-10.fs
openFPGALoader -b tangnano9k --verify -f --external-flash flash.txt