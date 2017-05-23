if [ -f /var/run/reboot-required ];
then
    echo "Reboot required!"
else
    echo "Reboot is not required."
fi

