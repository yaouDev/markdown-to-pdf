# base package - maintained which is nice
FROM pandoc/latex

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
COPY template/ /app/template/

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
