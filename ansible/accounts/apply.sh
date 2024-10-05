#!/bin/bash

ansible-playbook accounts.yml --extra-vars "main_user=$USER"
