#export MAIL_DOMAIN=yandex.ru
#export MAIL_LOGIN=USER
#export MAIL_PASSWORD=PASSWORD
#export MAIL_SMTP=smtp.yandex.ru

cd /etc/postfix
mkdir private
cd private
echo "@$MAIL_DOMAIN"$'\t'"$MAIL_LOGIN@$MAIL_DOMAIN" > canonical
echo "[$MAIL_SMTP]"$'\t'"$MAIL_LOGIN@$MAIL_DOMAIN:$MAIL_PASSWORD" > sasl_passwd
echo "@$MAIL_DOMAIN"$'\t'"$MAIL_SMTP" > sender_relay
