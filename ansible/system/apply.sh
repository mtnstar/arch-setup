sudo ansible-galaxy install -r requirements.yml

if [ $# -eq 0 ]; then
  sudo ansible-playbook system.yml --extra-vars "main_user=$USER"
else
  sudo ansible-playbook system.yml -t=$1 --extra-vars "main_user=$USER"
fi

exit 0
