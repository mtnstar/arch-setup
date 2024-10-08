#!/bin/bash

if [ $# -eq 0 ]; then
  ansible-playbook user.yml --extra-vars "main_user=$USER"
else
  ansible-playbook user.yml -t=$1 --extra-vars "main_user=$USER"
fi
