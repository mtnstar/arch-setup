sudo ansible-galaxy install -r requirements.yml

if [ $# -eq 0 ]; then
  sudo ansible-playbook desktop.yml --extra-vars "main_user=$USER"
else
  sudo ansible-playbook desktop.yml -t=$1 --extra-vars "main_user=$USER"
fi

ansible-playbook user.yml

exit 0
