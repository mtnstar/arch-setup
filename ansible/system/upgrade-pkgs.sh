#!/bin/bash

sudo pacman -Syu --noconfirm
sudo -u aur_builder yay -Syu --noconfirm
flatpak update -y
