#!/bin/sh

#Construído por Vinícius Oliveira - eu@viniciusoliveira.me

#Circuit Breaker para IXC

#Caso não consiga consultar um cliente pela API irá reiniciar os serviços e enviar um alerta pelo Telegram

#Motivos que podem acionar o Circuit Breaker:
#    -Pool FPM travado
#    -MySQL consumindo toda memória da máquina por conta da configuração padrão
#    -Problemas diversos com apache/nginx

#Status:
#0 - OK
#1 - Erro, houve tentativa de recuperar
#2 - Circuit Breaker desarmado (recuperação automática não funcionou)

#Deve ser adicionado ao Cron para ser executado de tempos em tempos

TOKEN="" #Token do Webservice do IXC - http://wiki.ixcsoft.com.br/index.php/Configura%C3%A7%C3%A3o_Webservice
URL="https://SEUIXC/webservice/v1/cliente"

TOKEN_TELEGRAM="" # Token gerado junto ao Bot do Telegram - https://medium.com/tht-things-hackers-team/10-passos-para-se-criar-um-bot-no-telegram-3c1848e404c4
CHAT_ID="" #ID do chat para onde será enviada a mensagem

TOKEN=$(echo -n $TOKEN | base64 | tr -d [:space:] );

LAST_RUN=`cat lastrun`

RETORNO=`curl -o /dev/null -s -w "%{http_code}" -L --request POST "$URL" \
--header 'Content-Type: application/json' \
--header 'ixcsoft: listar' \
--header "Authorization: Basic $TOKEN" \
--form 'qtype=cliente.id' \
--form 'query=1' \
--form 'oper==' \
--form 'page=1' \
--form 'rp=1' \
--form 'sortname=cliente.id' \
--form 'sortorder=desc' \
--max-time 10`

#RETORNO=$?

echo "\n"

if [ "$RETORNO" -ne "200" ]
then
    echo "$RETORNO - Erro!"

    if [ "$LAST_RUN" = "1" ]
    then

        curl -X POST \
            -H 'Content-Type: application/json' \
            -d "{\"chat_id\": \"$CHAT_ID\", \"text\": \"Circuit Breaker IXC desarmado - VERIFICAR\", \"disable_notifition\": true}" \
            "https://api.telegram.org/bot$TOKEN_TELEGRAM/sendMessage"

        echo "2" > lastrun;

    elif [ "$LAST_RUN" = "0" ]
    then

        curl -X POST \
            -H 'Content-Type: application/json' \
            -d "{\"chat_id\": \"$CHAT_ID\", \"text\": \"Circuit Breaker IXC desarmado - Reiniciando serviços...\", \"disable_notifition\": true}" \
            "https://api.telegram.org/bot$TOKEN_TELEGRAM/sendMessage"

        echo "1" > lastrun;

        echo "Reniciando serviços..."

        service php7.3-fpm restart
#        service nginx restart
#        service mariadb restart

        echo "Serviços reniciados"
    fi

else
    echo "200 - OK!"

    if [ "$LAST_RUN" -ne "0" ]
    then

        curl -X POST \
            -H 'Content-Type: application/json' \
            -d "{\"chat_id\": \"$CHAT_ID\", \"text\": \"Circuit Breaker IXC armado novamente - Serviços funcionando normalmente\", \"disable_notifition\": true}" \
            "https://api.telegram.org/bot$TOKEN_TELEGRAM/sendMessage"

    fi

    echo "0" > lastrun;

fi
