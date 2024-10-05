#!/bin/bash

ansible-playbook user.yml --extra-vars "main_user=$USER"
